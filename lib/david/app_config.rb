module David
  class AppConfig < Hash
    DEFAULT_OPTIONS = {
      :Block => true,
      :CBOR => false,
      :DefaultFormat => 'application/json',
      :Host => ENV['RACK_ENV'] == 'development' ? '::1' : '::',
      :Log => nil,
      :Multicast => true,
      :Observe => true,
      :Port => ::CoAP::PORT,
      :Prefork => 0
    }

    def initialize(hash)
      self.merge!(DEFAULT_OPTIONS)
      self.merge!(hash)
      self.keys.each { |key| optionize!(key) }
    end

    private

    def choose_block(value)
      default_to_true(:block, value)
    end

    def choose_cbor(value)
      default_to_false(:cbor, value)
    end

    def choose_defaultformat(value)
      value = from_rails(:default_format, value)
      return nil if value.nil?
      value
    end

    # Rails starts on 'localhost' since 4.2.0.beta1
    # (Resolv class seems not to consider /etc/hosts)
    def choose_host(value)
      return nil if value.nil?
      Socket::getaddrinfo(value, nil, nil, Socket::SOCK_STREAM)[0][3]
    end

    def choose_log(value)
      fd = $stderr
      level = ::Logger::INFO

      case value
      when 'debug'
        level = ::Logger::DEBUG
      when 'none'
        fd = File.open('/dev/null', 'w')
        level = ::Logger::FATAL
      end

      log = ::Logger.new(fd)
      log.level = level
      log.formatter = proc do |sev, time, prog, msg|
        "#{time.strftime('[%Y-%m-%d %H:%M:%S]')} #{sev}  #{msg}\n"
      end

      Celluloid.logger = log

      log
    end

    def choose_multicast(value)
      default_to_true(:multicast, value)
    end
    
    def choose_observe(value)
      default_to_true(:observe, value)
    end

    def choose_port(value)
      value.nil? ? nil : value.to_i
    end

    def choose_prefork(value)
      return nil if value.nil?
      value.to_i
    end
  
    def default_to_false(key, value)
      value = from_rails(key, value)
      return false if value.nil? || value.to_s == 'false'
      true
    end
  
    def default_to_true(key, value)
      value = from_rails(key, value)
      return true if value.nil? || value.to_s == 'true'
      false
    end

    def from_rails(key, value)
      if value.nil? && defined?(Rails)
        Rails.application.config.coap.send(key)
      end
    end

    def optionize!(key)
      method = ('choose_' << key.to_s.downcase).to_sym
      value = self.send(method, self[key])
      self[key] = value unless value.nil?
    end
  end
end
