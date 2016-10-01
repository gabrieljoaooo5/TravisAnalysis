#!/usr/bin/env ruby
#file: projectInfo.rb

require 'travis'
require 'csv'
require 'fileutils'
require 'find'
require_relative 'GitProject.rb'

class ProjectInfo

	def initialize(pathAnalysis)
		@pathAnalysis = pathAnalysis
		@pathProjects = Array.new
		findPathProjects() 
	end

	def getPathAnalysis()
		@pathAnalysis
	end

	def getPathProjects()
		@pathProjects
	end

	def getProjectNames()
		@projectNames
	end

	def findPathProjects()
		Find.find(@pathAnalysis) do |path|
	  		@pathProjects << path if path =~ /.*\.travis.yml$/
		end
		@pathProjects.sort_by!{ |e| e.downcase }

	end

end