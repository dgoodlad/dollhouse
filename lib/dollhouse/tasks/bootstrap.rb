module Dollhouse
  module Tasks
    module Bootstrap
      DEFAULT_BOOTSTRAP_OPTIONS = {
        :apt_mirror => 'http://mirror.internode.on.net/pub/ubuntu/ubuntu',
        :apt_distro => 'lucid'
      }

      # Bootstrap a new server
      # - Update apt sources
      # - Install babushka
      #
      # NOTE: Requires that you can login as a user with sudo access
      def bootstrap(options = {})
        raise "Bootstrap requires root access" unless connected_as_root?

        options = DEFAULT_BOOTSTRAP_OPTIONS.merge(options)

        set_apt_mirror(options[:apt_mirror], options[:apt_distro])
        update_apt
        bootstrap_babushka(options[:babushka_bootstrap_url])

        if options[:babushka_sources]
          clear_babushka_sources
          options[:babushka_sources].each do |source|
            add_babushka_source *source
          end
        end
      end
    end
  end
end
