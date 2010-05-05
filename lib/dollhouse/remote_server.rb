require 'net/ssh'
require 'net/sftp'
require 'tempfile'

module Dollhouse
  class RemoteServer
    include Dollhouse::Tasks::Babushka

    attr_reader :ssh
    
    def initialize(ssh)
      @ssh = ssh
    end
    
    def log(message)
      puts message
    end

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
          output << "ERR: #{data}"
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
    
    def self.connect(host, user, password, &block)
      puts "Connecting to #{host} as #{user}..."
      Net::SSH.start(host, user, :password => password) do |ssh|
        server = new(ssh)
        
        server.instance_eval(&block)
      end
    end
    
    def self.set_root_password(host, username, password)
      connect(host, username, password) do
        log.info "set root password" do
          ssh.exec! "sudo passwd root" do |ch, stream, data|
            if data =~ /password for #{username}\:/ || data =~ /(Enter|Retype) new UNIX password\:/
              ch.send_data("#{password}\n")
            elsif data =~ /password updated successfully/
              log.info :good, "  password changed."
            else
              unless data =~ /\A\s*\Z/
                log.error data
                exit 1
              end
            end
          end
        end
      end
    end
    
    def install_runtime_environment(mirror)
      log.info "install runtime environment" do
        log.info "setup sources.list for #{mirror}"
        upload_template 'templates/sources.list.erb', '/etc/apt/sources.list', :mirror => mirror

        log.info "apt-get update" do
          # This is running locally so can't alter the environment
          # ENV['DEBIAN_FRONTEND'] = 'noninteractive'
          exec_command 'apt-get update -y', true
        end

        log.info "apt-get upgrade" do
          # This is running locally so can't alter the environment
          #ENV['DEBIAN_FRONTEND'] = 'noninteractive'
          exec_command 'apt-get upgrade -y', true
        end

        install_ree_from_package
        # install_rvm
        # install_ree_from_rvm

        log.info "install other packages" do
          exec_command 'apt-get install -y pcregrep pwgen', true
        end
      end
    end  
  end
end
