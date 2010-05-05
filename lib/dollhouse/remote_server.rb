require 'net/ssh'
require 'net/sftp'
require 'tempfile'

module Dollhouse
  class RemoteServer
    include Dollhouse::Tasks::Babushka
    include Dollhouse::Tasks::Bootstrap

    attr_reader :ssh

    # Connect to a remote server, and execute the given block within the
    # context of that server.
    # If you don't supply a password, pubkey authentication should take over.
    def self.connect(host, user, password = nil, &block)
      puts "Connecting to #{host} as #{user}..."
      Net::SSH.start(host, user, :password => password) do |ssh|
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
      output = ""
      
      @ssh.exec!("(#{command}) && echo SUCCESS || echo FAILURE $?") do |ch, stream, data|
        if stream == :stderr
          puts "ERR: #{data}"
        else # stdout
          output << data
        end
      end
      
      if output =~ /\A(.*)(SUCCESS|FAILURE)( \d+)?\n\Z/m
        result = [$2 == 'SUCCESS', $1, $3.to_i]
      else
        raise "weird #{output.inspect}"
      end

      puts output
      
      block_given? ? yield(result) : result
    end
    
    def get_environment(var)
      @ssh.exec!("echo $#{var}").strip
    end

    def connected_as_root?
      @ssh.exec!("id") =~ /^uid=0\(root\)/
    end
  end    
end
