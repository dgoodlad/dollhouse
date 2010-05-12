require 'net/ssh'
require 'net/sftp'
require 'tempfile'

module Dollhouse
  class RemoteServer
    class FailedRemoteCommand < Exception; end

    include Net::SSH::Prompt

    include Dollhouse::Tasks::Apt
    include Dollhouse::Tasks::Babushka
    include Dollhouse::Tasks::Bootstrap

    attr_reader :ssh

    # Connect to a remote server, and execute the given block within the
    # context of that server.
    # If you don't supply a password, pubkey authentication should take over.
    def self.connect(host, user, options = {}, &block)
      puts "Connecting to #{host} as #{user}..."
      Net::SSH.start(host, user, options) do |ssh|
        new(ssh).instance_eval(&block)
      end
    end

    def initialize(ssh)
      @ssh = ssh
    end

    # Write to a remote file at _path_.
    def write_file(path)
      Tempfile.open(File.basename(path)) do |f|
        yield f
        f.flush
        @ssh.sftp.upload!(f.path, path)
      end
    end

    def exec(command)
      # For now, we'll always request a pty; this is not necessarily
      # what we really want, but it'll do.
      exec_with_pty(command)
    end

    def exec_with_pty(command)
      channel = @ssh.open_channel do |ch|
        ch.request_pty do |ch, success|
          raise "Failed to get a PTY!" unless success

          output = ''

          puts "Executing:\n#{command}"

          ch.exec("(#{command}) && echo SUCCESS || echo FAILURE $?") do |ch, success|
            raise "Failed to start execution!" unless success

            ch.on_data do |ch, data|
              print data
              if data =~ /[Pp]assword.+:/
                ch.send_data("#{prompt("", false)}\n")
              end

              output << data
            end

            ch.on_extended_data do |ch, data|
              print data
            end
          end
          ch.wait

          if output =~ /\A(.*)(SUCCESS|FAILURE)( \d+)?\r?\n\Z/m
            raise FailedRemoteCommand, "Status code: #{$3}" if $2 == 'FAILURE'
            result = [$2 == 'SUCCESS', $1, $3.to_i]
          else
            raise "weird #{output.inspect}"
          end

          block_given? ? yield(result) : result
        end
      end
      channel.wait
    end

    def get_environment(var)
      @ssh.exec!("echo $#{var}").strip
    end

    def connected_as_root?
      @ssh.exec!("id") =~ /^uid=0\(root\)/
    end
  end
end
