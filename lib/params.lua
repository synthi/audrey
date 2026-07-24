-- params.lua
-- v6.0.0 - Parameter mappings faithful to Audrey-II C++ original
-- 11 parameters matching FeedbackSynthControls.cpp
--
-- C++ original parameter list:
--   Frequency (16-72 nn, lin, smooth 0.2s)
--   FeedbackGain (-60 to 12 dB, lin, smooth 0.05s)
--   FeedbackBody (0.001-0.1 s, exp, smooth 1.0s)
--   FeedbackLPFCutoff (100-18000 Hz, log, smooth 0.05s)
--   FeedbackHPFCutoff (10-4000 Hz, log, smooth 0.05s)
--   ReverbMix (0-1, lin, smooth 0.05s)
--   ReverbDecay (0.2-1.0, lin, smooth 0.05s)
--   EchoDelaySend (0-1, exp, smooth 0.05s)
--   EchoDelayTime (0.05-5.0 s, exp, smooth 0.1s)
--   EchoDelayFeedback (0-1.5, lin, smooth 0.05s)
--   OutputVolume (0-1, exp, smooth 0.05s)

local Params = {}
local musicutil = require("musicutil")

function Params.init_params()
  params:add_separator("syn_sep", "SYNTHESIS")

  params:add{
    type = "control",
    id = "frequency",
    name = "Frequency",
    controlspec = controlspec.new(16, 72, "lin", 1, 40, "nn"),
    formatter = function(param)
      local nn = math.floor(param:get())
      local names = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
      local oct = math.floor(nn / 12) - 1
      local note = names[(nn % 12) + 1]
      return note .. oct .. " (" .. string.format("%.1f", musicutil.note_num_to_freq(nn)) .. "Hz)"
    end,
    action = function(x) engine.frequency(x) end
  }

  params:add{
    type = "control",
    id = "feedback_gain",
    name = "Feedback Gain",
    controlspec = controlspec.new(-60, 12, "lin", 0.1, -60, "dB"),
    action = function(x) engine.feedbackGain(x) end
  }

  params:add{
    type = "control",
    id = "feedback_body_delay",
    name = "Feedback Body",
    controlspec = controlspec.new(0.001, 0.1, "exp", 0.001, 0.001, "s"),
    action = function(x) engine.feedbackBodyDelay(x) end
  }

  params:add_separator("flt_sep", "FILTERS")

  params:add{
    type = "control",
    id = "lpf_cutoff",
    name = "Lowpass Cutoff",
    controlspec = controlspec.new(100, 18000, "exp", 1, 18000, "Hz"),
    action = function(x) engine.lpfCutoff(x) end
  }

  params:add{
    type = "control",
    id = "hpf_cutoff",
    name = "Highpass Cutoff",
    controlspec = controlspec.new(10, 4000, "exp", 1, 250, "Hz"),
    action = function(x) engine.hpfCutoff(x) end
  }

  params:add_separator("rev_sep", "REVERB")

  params:add{
    type = "control",
    id = "reverb_mix",
    name = "Reverb Mix",
    controlspec = controlspec.new(0, 1, "lin", 0.01, 0.0, ""),
    action = function(x) engine.reverbMix(x) end
  }

  params:add{
    type = "control",
    id = "reverb_decay",
    name = "Reverb Decay",
    controlspec = controlspec.new(0.2, 1.0, "lin", 0.01, 0.2, ""),
    action = function(x) engine.reverbFeedback(x) end
  }

  params:add_separator("echo_sep", "ECHO")

  params:add{
    type = "control",
    id = "echo_send",
    name = "Echo Send",
    controlspec = controlspec.new(0.001, 1, "exp", 0.01, 0.0, ""),
    action = function(x) engine.echoSend(x) end
  }

  params:add{
    type = "control",
    id = "echo_time",
    name = "Echo Time",
    controlspec = controlspec.new(0.05, 5.0, "exp", 0.01, 0.5, "s"),
    action = function(x) engine.echoTime(x) end
  }

  params:add{
    type = "control",
    id = "echo_feedback",
    name = "Echo Feedback",
    controlspec = controlspec.new(0, 1.5, "lin", 0.01, 0.0, ""),
    action = function(x) engine.echoFeedback(x) end
  }

  params:add_separator("out_sep", "OUTPUT")

  params:add{
    type = "control",
    id = "master_level",
    name = "Master Level",
    controlspec = controlspec.new(0.001, 1, "exp", 0.01, 0.5, ""),
    action = function(x) engine.masterLevel(x) end
  }

  params:bang()
end

return Params