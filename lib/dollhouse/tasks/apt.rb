module Dollhouse
  module Tasks
    module Apt
      def set_apt_mirror(mirror, distro)
        write_file "sources.list" do |f|
          # TODO extract this into an erb template or something
          f << <<-EOF
## Main #{distro} repository
deb #{mirror} #{distro} main restricted
deb-src #{mirror} #{distro} main restricted

## Major bug fix updates produced after the final release of the
## distribution
deb #{mirror} #{distro}-updates main restricted
deb-src #{mirror} #{distro}-updates main restricted

## Universe
deb #{mirror} #{distro} universe
deb-src #{mirror} #{distro} universe
deb #{mirror} #{distro}-updates universe
deb-src #{mirror} #{distro}-updates universe

## Multiverse
deb #{mirror} #{distro} multiverse
deb-src #{mirror} #{distro} multiverse
deb #{mirror} #{distro}-updates multiverse
deb-src #{mirror} #{distro}-updates multiverse

## Security updates
deb http://security.ubuntu.com/ubuntu #{distro}-security main restricted
deb-src http://security.ubuntu.com/ubuntu #{distro}-security main restricted
deb http://security.ubuntu.com/ubuntu #{distro}-security universe
deb-src http://security.ubuntu.com/ubuntu #{distro}-security universe
deb http://security.ubuntu.com/ubuntu #{distro}-security multiverse
deb-src http://security.ubuntu.com/ubuntu #{distro}-security multiverse
          EOF
        end

        exec "sudo cp /etc/apt/sources.list /etc/apt/sources.list.dollhouse-bak"
        exec "sudo mv sources.list /etc/apt/sources.list"
        exec "sudo chown root:root /etc/apt/sources.list"
      end

      def update_apt
        exec "sudo aptitude update"
      end
    end
  end
end
