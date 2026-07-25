-- params.lua
-- v7.0.1 - Continuous frequency with magnetic snap + 11 params matching C++ original

local Params = {}
local musicutil = require("musicutil")

function Params.init_params()
  params:add_separator("syn_sep", "SYNTHESIS")

  params:add{
    type = "control",
    id = "frequency",
    name = "Frequency",
    controlspec = controlspec.new(16, 72, "lin", 0.001, 40, ""),
    formatter = function(param)
      local val = param:get()
      local nearest_nn = math.floor(val + 0.5)
      local dist = math.abs(val - nearest_nn)
      if dist < 0.2 then
        local names = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
        local oct = math.floor(nearest_nn / 12) - 1
        local note = names[(nearest_nn % 12) + 1]
        return note .. oct .. " (" .. string.format("%.1f", musicutil.note_num_to_freq(nearest_nn)) .. "Hz)"
      else
        return string.format("%.1f Hz", musicutil.note_num_to_freq(val))
      end
    end,
    action = function(x) engine.frequency(x) end
  }

  params:add{
    type = "control",
    id = "feedback_gain",
    name = "Feedback Gain",
    controlspec = controlspec.new(-60, 12, "lin", 0.01, 0.8, "dB"),
    action = function(x) engine.feedbackGain(x) end
  }

  params:add{
    type = "control",
    id = "feedback_body_delay",
    name = "Feedback Body",
    controlspec = controlspec.new(0.001, 0.1, "lin", 0.0001, 0.001, "s"),
    action = function(x) engine.feedbackBodyDelay(x) end
  }

  params:add_separator("flt_sep", "FILTERS")

  params:add{
    type = "control",
    id = "lpf_cutoff",
    name = "Lowpass Cutoff",
    controlspec = controlspec.new(100, 18000, "lin", 0.1, 18000, "Hz"),
    action = function(x) engine.lpfCutoff(x) end
  }

  params:add{
    type = "control",
    id = "hpf_cutoff",
    name = "Highpass Cutoff",
    controlspec = controlspec.new(10, 4000, "lin", 0.1, 250, "Hz"),
    action = function(x) engine.hpfCutoff(x) end
  }

  params:add_separator("rev_sep", "REVERB")

  params:add{
    type = "control",
    id = "reverb_mix",
    name = "Reverb Mix",
    controlspec = controlspec.new(0, 1, "lin", 0.001, 0.0, ""),
    action = function(x) engine.reverbMix(x) end
  }

  params:add{
    type = "control",
    id = "reverb_decay",
    name = "Reverb Decay",
    controlspec = controlspec.new(0.2, 1.0, "lin", 0.001, 0.2, ""),
    action = function(x) engine.reverbFeedback(x) end
  }

  params:add_separator("echo_sep", "ECHO")

  params:add{
    type = "control",
    id = "echo_send",
    name = "Echo Send",
    controlspec = controlspec.new(0.001, 1, "lin", 0.001, 0.0, ""),
    action = function(x) engine.echoSend(x) end
  }

  params:add{
    type = "control",
    id = "echo_time",
    name = "Echo Time",
    controlspec = controlspec.new(0.05, 5.0, "lin", 0.001, 0.5, "s"),
    action = function(x) engine.echoTime(x) end
  }

  params:add{
    type = "control",
    id = "echo_feedback",
    name = "Echo Feedback",
    controlspec = controlspec.new(0, 1.5, "lin", 0.001, 0.0, ""),
    action = function(x) engine.echoFeedback(x) end
  }

  params:add_separator("out_sep", "OUTPUT")

  params:add{
    type = "control",
    id = "master_level",
    name = "Master Level",
    controlspec = controlspec.new(0.001, 1, "lin", 0.001, 0.5, ""),
    action = function(x) engine.masterLevel(x) end
  }

  params:bang()
end

return Params