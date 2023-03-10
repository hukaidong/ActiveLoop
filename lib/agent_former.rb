# frozen_string_literal: true

require 'English'
require 'yaml'
require 'tempfile'
require 'open3'
require 'shellwords'
require_relative 'config_loader'
require_relative 'active_learning/agent_former_config_renderer'

module AgentFormer
  extend ConfigLoader
  CONFIG = load_config('config/agentformer.yml')
  PROJECT_BASE = Snapshot.make_snapshot(CONFIG['agent_former_base'])
  private_constant :CONFIG, :PROJECT_BASE

  def self.temp_af_config(preserve: false)
    af_config_path = File.expand_path('cfg/tmp', PROJECT_BASE)
    if preserve
      Tempfile.create(%w[auto-generated- .yml], tmpdir = af_config_path)
    else
      Tempfile.new(%w[auto-generated- .yml], tmpdir = af_config_path)
    end
  end

  ##
  # Agentformer must be run under it's project root
  # This function ensures working directory
  def self.agentformer_exec(cmd, message: nil)
    pid = spawn(cmd, chdir: PROJECT_BASE)
    Process.wait(pid)

    unless $CHILD_STATUS&.success?
      warn(message)
      raise "Agentformer program exited with error code #{$CHILD_STATUS&.exitstatus}"
    end
  end
  private_class_method :temp_af_config, :agentformer_exec

  ##
  # Call Agentformer learn from given config
  # require config rendered by
  def self.call_agentformer(config_render, load: :auto, dry_run: false)
    tmpcfg = temp_af_config
    config_content = config_render.render('agentformer').tap do |x|
      tmpcfg.write(x)
      tmpcfg.flush
    end

    config_id = File.basename(tmpcfg.path, ".yml")
    cmd = CONFIG['python_path'].shellsplit
    cmd << "model_train.py"
    cmd << "--cfg" << config_id
    case load
    when :auto
      cmd << "--auto_load"
    when Integer
      cmd << "--start_epoch" << load
    when :disabled
      # no-op
    else
      raise ArgumentError, "Unrecognized option - load: #{load}"
    end
    return [cmd.shelljoin, config_content] if dry_run

    log = agentformer_exec(cmd.shelljoin, message: config_content)
  end

  def self.call_latent_dump
    tmpcfg = temp_af_config
    config_content = renderer_instance.render('agentformer').tap do |x|
      tmpcfg.write(x)
      tmpcfg.flush
    end

    config_id = File.basename(tmpcfg.path, ".yml")
    cmd = "#{CONFIG['python_path']} latent_gen.py --cfg #{config_id}"

    agentformer_exec("#{cmd} --data_eval train", message: config_content)
    agentformer_exec("#{cmd} --data_eval val", message: config_content)
  end
end
