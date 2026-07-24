// Engine_Audrey.sc
// v6.0.0 - Faithful port of Audrey-II (Daisy Seed C++) for norns
// Based on original by infrasonic/synthi
//
// Signal flow (matching FeedbackSynthEngine.cpp::Process):
//   noise(-90dB) + audio_in + fb_return → KS resonator → overdrive(tanh)
//   → LPF12(Q=0.9) → HPF12(Q=0.9) → Reverb(8comb+4allpass, INSIDE loop)
//   → reverb_mix → fb_write(*gain) → echo(BPF800+tanh) → mix(0.5) → limiter(0.7)
//
// All variables declared at top. Execution strictly top-to-bottom.

Engine_Audrey : CroneEngine {
    var <synth;

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {

        // === MAIN VOICE SYNTHDEF (single, self-contained) ===
        // Matches C++ Engine::Process + KarplusString + EchoDelay + ReverbSc

        SynthDef(\audreyVoice, {
            arg out=0, in=0,
                freq=40,        // MIDI note number (C++ original: 16-72)
                fbGain=-60,     // dBFS (C++ original: -60 to 12)
                body=0.001,     // seconds (C++ original: 0.001 to 0.1, exp)
                lpf=18000,      // Hz (C++ original: 100 to 18000, log)
                hpf=250,        // Hz (C++ original: 10 to 4000, log, default 250 in Controls)
                verbMix=0.0,    // 0-1 (C++ original: 0.0 default)
                verbFb=0.2,     // 0.2-1.0 (C++ original: 0.2 default)
                echoSend=0.0,   // 0-1 (C++ original: 0.0 default, exp)
                echoTime=0.5,   // seconds (C++ original: 0.05 to 5.0, exp)
                echoFb=0.0,     // 0-1.5 (C++ original: 0.0 default)
                level=0.5;      // 0-1 (C++ original: 0.5 default, exp)

            // ============================================
            // ALL VARIABLES DECLARED AT TOP (SC convention)
            // ============================================

            // Sample rate and constants
            var sr, sampleDur;

            // Smoothed parameters (Lag.kr matching C++ SmoothedValue)
            var kFreq, kBody, kFbAmp, kLpf, kHpf;
            var kVerbMix, kVerbFb, kEchoSend, kEchoTime, kEchoFb, kLevel;

            // Audio input and noise
            var audioIn, noise;

            // Feedback returns (4 channels: 2 main + 2 echo)
            var fbRetL, fbRetR, echoRetL, echoRetR;

            // Main loop signals
            var inL, inR, sampL, sampR;
            var verbL, verbR;

            // KS resonator
            var maxDelay, delayTime, decayTime;

            // Echo delay
            var echoTapeL, echoTapeR, echoOutL, echoOutR;

            // Reverb internals
            var combFb, combMult;
            var combL1, combL2, combL3, combL4;
            var combR1, combR2, combR3, combR4;
            var combL, combR, apL, apR;

            // ============================================
            // EXECUTION STARTS HERE (top to bottom)
            // ============================================

            sr = SampleRate.ir;
            sampleDur = SampleDur.ir;

            // --- Smoothed parameters (matching C++ SmoothedValue times) ---
            kFreq = Lag.kr(freq, 0.2).midicps;     // C++: 0.2s smooth, MIDI→Hz
            kBody = Lag.kr(body, 1.0);              // C++: 1.0s smooth
            kFbAmp = Lag.kr(fbGain, 0.05).dbamp;   // C++: 0.05s smooth, dB→linear
            kLpf = Lag.kr(lpf, 0.05);               // C++: 0.05s smooth
            kHpf = Lag.kr(hpf, 0.05);               // C++: 0.05s smooth
            kVerbMix = Lag.kr(verbMix, 0.05);       // C++: 0.05s smooth
            kVerbFb = Lag.kr(verbFb, 0.05);          // C++: 0.05s smooth
            kEchoSend = Lag.kr(echoSend, 0.05);     // C++: 0.05s smooth
            kEchoTime = Lag.kr(echoTime, 0.5);      // C++: 0.5s lag in EchoDelay
            kEchoFb = Lag.kr(echoFb, 0.05);         // C++: 0.05s smooth
            kLevel = Lag.kr(level, 0.05);           // C++: 0.05s smooth

            // --- Audio input (L+R sumados, -6dB para compensar) ---
            // C++ original usa solo IN_L; nosotros sumamos L+R con atenuación
            audioIn = In.ar(in, 2).sum * 0.5;

            // --- Noise seed (-90 dBFS, single instance shared L+R) ---
            // C++: noise_.SetAmp(dbfs2lin(-90.0f)) = 0.00003162
            noise = WhiteNoise.ar(-90.dbamp);

            // --- Feedback returns (4 channels: 2 main + 2 echo) ---
            #fbRetL, fbRetR, echoRetL, echoRetR = LocalIn.ar(4);

            // ============================================
            // MAIN FEEDBACK LOOP
            // (matching FeedbackSynthEngine.cpp::Process)
            // ============================================

            // --- 1. Body delay + noise + audio input ---
            // C++: inL = fb_delayline_[0].Read(fb_delay_samp_) + noise_samp + in;
            // C++: inR = fb_delayline_[1].Read(fmax(1.0, fb_delay_samp_ - 4)) + noise_samp + in;
            // R channel: 4 samples less delay for stereo decorrelation
            inL = DelayC.ar(fbRetL, 0.25, kBody) + noise + audioIn;
            inR = DelayC.ar(fbRetR, 0.25, (kBody - (4 * sampleDur)).max(sampleDur)) + noise + audioIn;

            // --- 2. KS Resonator (matching KarplusString.cpp) ---
            // C++: string_.ReadHermite(delay) + in → clip(±20) → DC block → *0.8 → Tone(8000Hz) → string_.Write
            //
            // CombL decay matches *0.8 feedback gain:
            // decaytime = -3 / log10(0.8) * (1/freq) = 13.45 / freq
            // Tone filter @ 8000Hz is transparent at 48kHz (coef clamps to 0)
            maxDelay = 8192 / sr;
            delayTime = kFreq.reciprocal.clip(4 / sr, maxDelay);
            decayTime = 13.45 / kFreq;

            sampL = CombL.ar(inL, maxDelay, delayTime, decayTime);
            sampR = CombL.ar(inR, maxDelay, delayTime, decayTime);

            // KS internal: clip ±20, DC block
            // (*0.8 already in decayTime, Tone@8000Hz transparent at 48kHz)
            sampL = sampL.clip(-20, 20);
            sampR = sampR.clip(-20, 20);
            sampL = LeakDC.ar(sampL);
            sampR = LeakDC.ar(sampR);

            // --- 3. Overdrive (soft clip, matching daisysp::Overdrive) ---
            // C++: overdrive_[i].SetDrive(0.4); sampL = overdrive_[0].Process(sampL);
            // DaisySP Overdrive uses soft clipping (tanh-like curve)
            // Drive=0.4 approximated as 1.8x gain into tanh
            sampL = (sampL * 1.8).tanh;
            sampR = (sampR * 1.8).tanh;

            // --- 4. Filters (LPF12 + HPF12, Q=0.9, matching C++ BiquadCascade) ---
            // C++: fb_lpf_.ProcessStereo(sampL, sampR); // LPF12, Q=0.9
            // C++: fb_hpf_.ProcessStereo(sampL, sampR); // HPF12, Q=0.9
            sampL = BLowPass.ar(sampL, kLpf, 1/0.9);
            sampR = BLowPass.ar(sampR, kLpf, 1/0.9);
            sampL = BHiPass.ar(sampL, kHpf, 1/0.9);
            sampR = BHiPass.ar(sampR, kHpf, 1/0.9);

            // --- 5. Reverb (DENTRO del feedback loop, matching C++ ReverbSc) ---
            // C++: verb_->Process(sampL, sampR, &verbL, &verbR);
            // C++: sampL -= (sampL - verbL) * verb_mix_;
            //
            // ReverbSc is a FreeVerb clone: 8 combs + 4 allpass + damping LPF
            // Our custom implementation uses same FreeVerb prime numbers

            // Convert feedback coefficient to CombL decaytime multiplier
            // decaytime = -3 / log10(fb) * delaytime
            // Clamp to prevent infinite decay at fb=1.0
            combFb = kVerbFb.min(0.999).max(0.001);
            combMult = -3 / combFb.log10;

            // LEFT: 4 parallel combs (FreeVerb prime numbers)
            combL1 = CombL.ar(sampL, 1116/sr, 1116/sr, combMult * 1116/sr);
            combL2 = CombL.ar(sampL, 1188/sr, 1188/sr, combMult * 1188/sr);
            combL3 = CombL.ar(sampL, 1277/sr, 1277/sr, combMult * 1277/sr);
            combL4 = CombL.ar(sampL, 1356/sr, 1356/sr, combMult * 1356/sr);
            combL = (combL1 + combL2 + combL3 + combL4) * 0.25;
            combL = LPF.ar(combL, 12000);  // ReverbSc SetLpFreq(12000)

            // LEFT: 2 series allpass (FreeVerb)
            apL = AllpassL.ar(combL, 225/sr, 225/sr, 0.5);
            apL = AllpassL.ar(apL, 556/sr, 556/sr, 0.5);

            // RIGHT: 4 parallel combs (FreeVerb prime numbers)
            combR1 = CombL.ar(sampR, 1422/sr, 1422/sr, combMult * 1422/sr);
            combR2 = CombL.ar(sampR, 1491/sr, 1491/sr, combMult * 1491/sr);
            combR3 = CombL.ar(sampR, 1557/sr, 1557/sr, combMult * 1557/sr);
            combR4 = CombL.ar(sampR, 1617/sr, 1617/sr, combMult * 1617/sr);
            combR = (combR1 + combR2 + combR3 + combR4) * 0.25;
            combR = LPF.ar(combR, 12000);

            // RIGHT: 2 series allpass (FreeVerb)
            apR = AllpassL.ar(combR, 341/sr, 341/sr, 0.5);
            apR = AllpassL.ar(apR, 441/sr, 441/sr, 0.5);

            // Reverb mix: sig - (sig - wet) * mix (matching C++ exactly)
            verbL = apL;
            verbR = apR;
            sampL = sampL - ((sampL - verbL) * kVerbMix);
            sampR = sampR - ((sampR - verbR) * kVerbMix);

            // ============================================
            // ECHO DELAY (matching EchoDelay.h)
            // ============================================

            // C++ EchoDelay::Process:
            //   out = delayLine_.Read();
            //   out = bpf_.Process(out);      // BPF12 @ 800Hz, Q=1.0
            //   out = daisysp::SoftClip(out); // tanh
            //   delayLine_.Write(out * feedback_ + in);
            //   return out;

            // BPF(800, 1.0) + SoftClip on echo feedback return
            echoTapeL = BPF.ar(echoRetL, 800, 1.0).tanh;
            echoTapeR = BPF.ar(echoRetR, 800, 1.0).tanh;

            // Delay with feedback (send from post-reverb signal)
            echoOutL = DelayC.ar((sampL * kEchoSend) + (echoTapeL * kEchoFb), 5, kEchoTime);
            echoOutR = DelayC.ar((sampR * kEchoSend) + (echoTapeR * kEchoFb), 5, kEchoTime);

            // ============================================
            // OUTPUT (matching C++ AudioCallback)
            // ============================================

            // C++: sampL = 0.5f * (sampL + echoL);
            // C++: outL = sampL * output_level_;
            // C++: limiter.ProcessBlock(OUT_L, size, 0.7f);
            sampL = 0.5 * (sampL + echoOutL);
            sampR = 0.5 * (sampR + echoOutR);

            // Output with inline limiter (threshold=0.7, matching C++)
            Out.ar(out, Limiter.ar([sampL, sampR] * kLevel, 0.7));

            // ============================================
            // FEEDBACK WRITE (cierra el loop)
            // ============================================

            // C++: fb_delayline_[0].Write(sampL * fb_gain_);
            // C++: fb_delayline_[1].Write(sampR * fb_gain_);
            // Main feedback with gain applied at write (like C++ original)
            // Echo feedback without additional gain (gain is in echoFb param)
            LocalOut.ar([sampL * kFbAmp, sampR * kFbAmp, echoOutL, echoOutR]);

        }).add;

        context.server.sync;

        // === Instantiate synth ===
        synth = Synth.new(\audreyVoice, [
            \out, context.out_b,
            \in, context.in_b
        ], target: context.xg);

        // === Commands (11, matching C++ FeedbackSynthControls) ===
        this.addCommand(\frequency, "f", { arg msg; synth.set(\freq, msg[1]); });
        this.addCommand(\feedbackGain, "f", { arg msg; synth.set(\fbGain, msg[1]); });
        this.addCommand(\feedbackBodyDelay, "f", { arg msg; synth.set(\body, msg[1]); });
        this.addCommand(\lpfCutoff, "f", { arg msg; synth.set(\lpf, msg[1]); });
        this.addCommand(\hpfCutoff, "f", { arg msg; synth.set(\hpf, msg[1]); });
        this.addCommand(\reverbMix, "f", { arg msg; synth.set(\verbMix, msg[1]); });
        this.addCommand(\reverbFeedback, "f", { arg msg; synth.set(\verbFb, msg[1]); });
        this.addCommand(\echoSend, "f", { arg msg; synth.set(\echoSend, msg[1]); });
        this.addCommand(\echoTime, "f", { arg msg; synth.set(\echoTime, msg[1]); });
        this.addCommand(\echoFeedback, "f", { arg msg; synth.set(\echoFb, msg[1]); });
        this.addCommand(\masterLevel, "f", { arg msg; synth.set(\level, msg[1]); });
    }

    free {
        synth.free;
    }
}