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
        ch.request_pty(:term => 'xterm-color') do |ch, success|
          raise "Failed to get a PTY!" unless success

          output = ''
          status_code = nil

          puts "Executing:\n#{command}"

          ch.exec(command) do |ch, success|
            raise "Failed to start execution!" unless success

            ch.on_data do |ch, data|
              if data =~ /[Pp]assword.+:/
                ch.send_data("#{prompt(data, false)}\n")
              elsif data =~ /continue connecting \(yes\/no\)\?/
                ch.send_data("#{prompt(data, true)}\n")
              else
                print data
              end

              output << data
            end

            ch.on_extended_data do |ch, data|
              print data
            end

            ch.on_request('exit-status') do |ch, data|
              status_code = data.read_long
            end
          end
          ch.wait

          unless status_code.zero?
            raise FailedRemoteCommand, "Status code: #{status_code}"
          end

          result = [status_code.zero?, output, status_code]
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
