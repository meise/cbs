#!/usr/bin/env ruby
# encoding: utf-8

=begin
Copyright Daniel Meißner <meise+check_backup_space@3st.be>, 2012

This file is part of a nagios check script to monitor available disk space on a
remote server, reached e.g. via sftp.

This script is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

It is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this script. If not, see <http://www.gnu.org/licenses/>.
=end

require 'rubygems'
require 'optparse'
require 'pathname'

# Using Semantic Versioning (2.0.0-rc.1) rules
# @see http://semver.org/
# @author Daniel Meißner

# Script to check disk space on remote systems via (s)ftp or ssh.
class Cbs

  NAME    = 'Cbs'
  VERSION = '0.0.1'

end

# Class to parse options from command line.
class Cbs::Parser

  # Run parser.
  #
  # @return [Hash] of options the parser detected.
  def self.run!
    options = {}

    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"

      opts.separator ""
      opts.separator "Required options:"

      opts.on("-H", "--host HOST", String, "Set backup host") do |host|
        options[:host] = host
      end

      opts.separator ""

      opts.on("-u", "--user USER", String,"Set user") do |user|
        options[:user] = user
      end

      opts.on("-p", "--password PASS", String,"Set user password") do |password|
        options[:password] = password
      end

      opts.separator ""

      opts.on("-w", "--warning SIZE", Integer,"Set space left warning limit in GB") do |warning|
        options[:warning] = warning
      end

      opts.on("-c", "--critical SIZE", Integer,"Set space left critical limit in GB") do |critical|
        options[:critical] = critical
      end

      opts.on("-m", "--maximum SIZE", Integer,"Set maximum of your backup space capacity in GB") do |quota|
        options[:quota] = quota
      end

      opts.separator ""
      opts.separator "Optional options:"

      opts.on("-f", "--file /etc/nagios/password", String,"Read password from file") do |file|
        options[:file] = Pathname(file)
      end

      opts.on("--protocol [PROTO]", ['sftp', 'ftp', 'ssh'],"Set set protocol to determine disk usage (default sftp)") do |protocol|
        options[:protocol] = protocol
      end

      opts.on("--[no]-verbose", "Run verbosely") do |verbose|
        options[:verbose] = verbose
      end

      opts.separator ""
      opts.separator "Common options:"

      opts.on_tail("-h", "--help", "Show this message") do
          puts opts
        exit
      end

      opts.on_tail("-v", "--version", "Show #{$0} version") do
        puts <<-MOEP
#{$0} - v#{Cbs::VERSION}
Released under the GNU GENERAL PUBLIC LICENSE Version 3. © Daniel Meißner, 2012
        MOEP

        exit 3
      end
    end.parse!

    self.check_arguments(options)
  end

  protected

  # Class method to check that all needed options are present. This function is only used in *run!* method.
  #
  # @param [Hash] options
  # @return [Hash]
  def self.check_arguments( options = {} )
    missing_arguments = []

    missing_arguments << "user"           if options[:user].nil?
    missing_arguments << "password"       if options[:password].nil?  and options[:file].nil?
    missing_arguments << "host"           if options[:host].nil?
    missing_arguments << "warning limit"  if options[:warning].nil?
    missing_arguments << "critical limit" if options[:critical].nil?

    if missing_arguments.size > 0
      puts "Missing arguments for #{missing_arguments.join(', ')}."

      exit 3
    end

    unless options[:file].nil?
      options[:password] = read_password(options[:file])
    end

    if options[:protocol].nil?
      options[:protocol] = 'sftp'
    end

    options
  end

  # Password can be read from password file. This method implements that functionality,
  #
  # @param [Pathname, String] file for password
  # @return [String] password read from file.
  def self.read_password(file)
    File.read( Pathname.new(file) ).chomp
  end
end

class Cbs::SpaceChecker
  # @return [String] password read from password file.s

  attr_reader :disk_usage, :free_space, :quota

  # @param [Hash] options
  def initialize( options = {} )
    @options    = options
    @disk_usage = get_disk_usage
    @quota      = @options[:quota]
    @free_space = calculate_free_space(@quota, @disk_usage)
  end

  # Function to check dependencies
  #
  # Lftp is used to check available disk space. This program must be installed.
  def check_dependencies
    @lftp = %x{which lftp}.chomp

    if @lftp.empty?
      puts 'Lftp program is missing.'
      exit 3
    end
  end

  # Connect to remote disk and returned disk usage as floating number.
  #
  # @return [Float] Disk usage.
  def get_disk_usage
    # result in bytes
    result = %x{#{@lftp} -u #{@options[:user]},#{@options[:password]} #{@options[:protocol]}://#{@options[:host]} -e "du -sb .; exit"}

    result.gsub(/\D/, '').to_f
  end

  # Calculates free disk space on given values.
  #
  # @param [Float, Float] quota quota limit and disk usage.
  # @return [Float] of free space.
  def calculate_free_space(quota, disk_usage)
    quota - (disk_usage/1024/1024/1024)
  end
end

# Interpreter class is used to interpret the results given by SpaceChecker.
class Cbs::Interpreter

  attr_accessor :status, :critical, :warning

  # @param [Integer, Integer, Float] warning
  def initialize(warning, critical, free_space)
    @warning    = warning
    @critical   = critical
    @free_space = free_space

    @status     = { :label => '', :exit_code => nil }
  end

  # @param [Integer, Integer, Float] warning
  # @return [Interpreter]
  def self.interpret(warning, critical, free_space)
    assesor = Cbs::Interpreter.new(warning, critical, free_space)
    assesor.interpret
  end

  # @return [Self]
  def interpret
    if @free_space < @warning
      if @free_space < @critical
        @status[:label]     = 'CRITICAL'
        @status[:exit_code] = 2
      else
        @status[:label]     = 'WARNING'
        @status[:exit_code] = 1
      end
    else
      @status[:label]     = 'OK'
      @status[:exit_code] = 0
    end

    self
  end
end

options       = Cbs::Parser.run!
space_checker = Cbs::SpaceChecker.new(options)
result        = Cbs::Interpreter.interpret(options[:warning], options[:critical], space_checker.free_space )

puts "BACKUP_SPACE #{result.status[:label]} - free space: #{space_checker.free_space.to_i}GB of #{space_checker.quota}GB (w: #{result.warning}GB c: #{result.critical}GB)"

exit result.status[:exit_code]