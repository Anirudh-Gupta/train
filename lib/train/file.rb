# encoding: utf-8
#
# author: Christoph Hartmann
# author: Dominik Richter

require 'train/file/local'
require 'train/file/remote'
require 'train/file/remote/unix'
require 'train/file/remote/linux'
require 'train/file/remote/windows'
require 'train/file/remote/qnx'
require 'train/extras/stat'

module Train
  class File
    def initialize(backend, path, follow_symlink = true)
      @backend = backend
      @path = path || ''
      @follow_symlink = follow_symlink

      sanitize_filename(path)
    end

    # This method gets override by particular os class.
    def sanitize_filename(_path)
      nil
    end

    # interface methods: these fields should be implemented by every
    # backend File
    DATA_FIELDS = %w{
      exist? mode owner group uid gid content mtime size selinux_label path
    }.freeze

    DATA_FIELDS.each do |m|
      define_method m.to_sym do
        fail NotImplementedError, "File must implement the #{m}() method."
      end
    end

    def to_json
      res = Hash[DATA_FIELDS.map { |x| [x, method(x).call] }]
      # additional fields provided as input
      res['type'] = type
      res['follow_symlink'] = @follow_symlink
      res
    end

    def type
      :unknown
    end

    def md5sum
      value = @backend.run_command("md5sum #{@path}").stdout.slice(0..31)
      if value.empty?
        value = nil
      end
      value
    rescue TypeError => _
      nil
    end

    def sha256sum
      value = @backend.run_command("sha256sum #{@path}").stdout.slice(0..63)
      if value.empty?
        value = nil
      end
      value
    rescue TypeError => _
      nil
    end

    def source
      if @follow_symlink
        self.class.new(@backend, @path, false)
      else
        self
      end
    end

    def source_path
      @path
    end

    # product_version is primarily used by Windows operating systems only and will be overwritten
    # in Windows-related classes. Since this field is returned for all file objects, the acceptable
    # default value is nil
    def product_version
      nil
    end

    # file_version is primarily used by Windows operating systems only and will be overwritten
    # in Windows-related classes. Since this field is returned for all file objects, the acceptable
    # default value is nil
    def file_version
      nil
    end

    def version?(version)
      product_version == version or
        file_version == version
    end

    def block_device?
      type.to_s == 'block_device'
    end

    def character_device?
      type.to_s == 'character_device'
    end

    def pipe?
      type.to_s == 'pipe'
    end

    def file?
      type.to_s == 'file'
    end

    def socket?
      type.to_s == 'socket'
    end

    def directory?
      type.to_s == 'directory'
    end

    def symlink?
      source.type.to_s == 'symlink'
    end

    def owned_by?(sth)
      owner == sth
    end

    def path
      if symlink? && @follow_symlink
        link_path
      else
        @path
      end
    end

    # if the OS-specific file class supports inquirying as to whether the
    # file/device is mounted, the #mounted method should return a command
    # object whose stdout will not be nil if indeed the device is mounted.
    #
    # if the OS-specific file class does not support checking for mount
    # status, the method should not be implemented and this method will
    # return false.
    def mounted?
      return false unless respond_to?(:mounted)

      !mounted.nil? && !mounted.stdout.nil? && !mounted.stdout.empty?
    end
  end
end