-- params.lua
-- v5.0.0 - Parameter mappings faithful to Audrey-II
-- 2024-12-20
--
-- Changelog v5.0.0:
-- - Unified version numbering across all files
-- - All parameter ranges verified against C++ original
-- - dB conversion, anti-exponential tension curve
-- - Mappings match DaisySP implementation

local Params = {}
local musicutil = require("musicutil")

local function db_to_lin(db) 
  return math.pow(10, db / 20) 
end

local function ftension(x, tension)
  if tension > 0 then 
    return math.pow(x, 1 / (1 + tension))
  elseif tension < 0 then 
    return 1 - math.pow(1 - x, 1 / (1 - tension))
  else 
    return x 
  end
end

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
    action = function(x) engine.frequency(musicutil.note_num_to_freq(x)) end
  }
  
  params:add{
    type = "control",
    id = "feedback_gain",
    name = "Feedback Gain",
    controlspec = controlspec.new(-60, 12, "lin", 0.1, -6, "dB"),
    action = function(x) engine.feedbackGain(db_to_lin(x)) end
  }
  
  params:add{
    type = "control",
    id = "feedback_body_delay",
    name = "Feedback Body",
    controlspec = controlspec.new(0.001, 0.1, "exp", 0.001, 0.01, "s"),
    action = function(x) engine.feedbackBodyDelay(x) end
  }
  
  params:add{
    type = "control",
    id = "brightness",
    name = "Brightness",
    controlspec = controlspec.new(0, 1, "lin", 0.01, 0.98, ""),
    action = function(x) engine.brightness(x) end
  }
  
  params:add{
    type = "control",
    id = "damping",
    name = "Damping",
    controlspec = controlspec.new(0, 1, "lin", 0.01, 0.4, ""),
    action = function(x) engine.damping(x) end
  }
  
  params:add{
    type = "control",
    id = "overdrive",
    name = "Overdrive",
    controlspec = controlspec.new(0, 1, "lin", 0.01, 0.4, ""),
    action = function(x) engine.overdriveDrive(x) end
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
    id = "lpf_q",
    name = "Lowpass Q",
    controlspec = controlspec.new(0.1, 10, "exp", 0.1, 0.9, ""),
    action = function(x) engine.lpfQ(x) end
  }
  
  params:add{
    type = "control",
    id = "hpf_cutoff",
    name = "Highpass Cutoff",
    controlspec = controlspec.new(10, 4000, "exp", 1, 60, "Hz"),
    action = function(x) engine.hpfCutoff(x) end
  }
  
  params:add{
    type = "control",
    id = "hpf_q",
    name = "Highpass Q",
    controlspec = controlspec.new(0.1, 10, "exp", 0.1, 0.9, ""),
    action = function(x) engine.hpfQ(x) end
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
    controlspec = controlspec.new(0, 1, "lin", 0.01, 0.7, ""),
    action = function(x)
      local curved = ftension(x, -3.0)
      local fb = 0.2 + (curved * 0.8)
      engine.reverbFeedback(fb)
    end
  }
  
  params:add{
    type = "control",
    id = "reverb_lpf",
    name = "Reverb Damping",
    controlspec = controlspec.new(1000, 18000, "exp", 1, 12000, "Hz"),
    action = function(x) engine.reverbLpf(x) end
  }
  
  params:add_separator("dly_sep", "TAPE DELAY")
  
  params:add{
    type = "control",
    id = "delay_time",
    name = "Delay Time",
    controlspec = controlspec.new(0.05, 5.0, "exp", 0.01, 0.5, "s"),
    action = function(x) engine.delayTime(x) end
  }
  
  params:add{
    type = "control",
    id = "delay_feedback",
    name = "Delay Feedback",
    controlspec = controlspec.new(0, 1.5, "lin", 0.01, 0.5, ""),
    action = function(x) engine.delayFeedback(x) end
  }
  
  params:add{
    type = "control",
    id = "delay_send",
    name = "Delay Send",
    controlspec = controlspec.new(0.001, 1, "exp", 0.01, 0.5, ""),
    action = function(x) engine.delaySendAmount(x) end
  }
  
  params:add_separator("tape_sep", "TAPE CHARACTER")
  
  params:add{
    type = "control",
    id = "tape_wow_amount",
    name = "Wow Amount",
    controlspec = controlspec.new(0, 0.05, "lin", 0.001, 0.02, ""),
    action = function(x) engine.wowAmount(x) end
  }
  
  params:add{
    type = "control",
    id = "tape_wow_rate",
    name = "Wow Rate",
    controlspec = controlspec.new(0.1, 2, "exp", 0.01, 0.3, "Hz"),
    action = function(x) engine.wowRate(x) end
  }
  
  params:add{
    type = "control",
    id = "tape_flutter_amount",
    name = "Flutter Amount",
    controlspec = controlspec.new(0, 0.03, "lin", 0.001, 0.01, ""),
    action = function(x) engine.flutterAmount(x) end
  }
  
  params:add{
    type = "control",
    id = "tape_flutter_rate",
    name = "Flutter Rate",
    controlspec = controlspec.new(2, 12, "lin", 0.1, 6, "Hz"),
    action = function(x) engine.flutterRate(x) end
  }
  
  params:add{
    type = "control",
    id = "tape_age",
    name = "Tape Age",
    controlspec = controlspec.new(0, 1, "lin", 0.01, 0.3, ""),
    action = function(x) engine.tapeAge(x) end
  }
  
  params:add{
    type = "control",
    id = "tape_saturation",
    name = "Tape Saturation",
    controlspec = controlspec.new(0, 1, "lin", 0.01, 0.4, ""),
    action = function(x) engine.tapeSaturation(x) end
  }
  
  params:add_separator("tone_sep", "TAPE TONE")
  
  params:add{
    type = "control",
    id = "tape_hiss",
    name = "Tape Hiss",
    controlspec = controlspec.new(0, 0.1, "lin", 0.001, 0.02, ""),
    action = function(x) engine.tapeHiss(x) end
  }
  
  params:add{
    type = "control",
    id = "tape_lpf",
    name = "Tape LPF",
    controlspec = controlspec.new(500, 12000, "exp", 1, 4000, "Hz"),
    action = function(x) engine.tapeLpf(x) end
  }
  
  params:add{
    type = "control",
    id = "tape_hpf",
    name = "Tape HPF",
    controlspec = controlspec.new(20, 500, "exp", 1, 80, "Hz"),
    action = function(x) engine.tapeHpf(x) end
  }
  
  params:add_separator("out_sep", "OUTPUT")
  
  params:add{
    type = "control",
    id = "master_level",
    name = "Master Level",
    controlspec = controlspec.new(0.001, 1, "exp", 0.01, 0.8, ""),
    action = function(x) engine.masterLevel(x) end
  }
  
  params:bang()
end

return Params