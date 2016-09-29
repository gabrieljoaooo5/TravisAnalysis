#!/usr/bin/env ruby
#file: buildTravis.rb

require 'travis'
require 'csv'
require 'rubygems'
require './Repository/MergeCommit.rb'
require './Travis/ConflictCategoryErrored.rb'
require './Travis/ConflictCategoryFailed.rb'
require './Data/ConflictAnalysis.rb'
require_relative 'ConflictBuild.rb'

class BuildTravis

	def initialize(projectName, projectPath)
		@projectName = projectName
		@projectPath = projectPath.gsub('.travis.yml', '')
		@gitProject = GitProject.new(projectPath)
		@projectMergeScenarios = @gitProject.getMergeScenarios()
	end

	def getProjectName()
		@projectName
	end

	def getProjectPath()
		@projectPath
	end

	def getMergeScenarios()
		@projectMergeScenarios
	end

	def mergeScenariosAnalysis(build)
		mergeCommit = MergeCommit.new()
		resultMergeCommit = mergeCommit.getParentsMergeIfTrue(@projectPath, build.commit.sha)
		return resultMergeCommit
	end

	def getStatusBuildsProject(projectName, pathResultByProject, pathConflicstAnalysis, pathMergeScenariosAnalysis, pathConflicsCauses)
		buildTotalPush = 0
		buildTotalPull = 0
		buildPushPassed = 0
		buildPushErrored = 0
		buildPushFailed = 0
		buildPushCanceled = 0
		buildPullPassed = 0
		buildPullErrored = 0
		buildPullFailed = 0
		buildPullCanceled = 0
		type = ""
		
		builtMergeScenarios = Array.new
		totalPushesNoBuilt = 0
		totalPushes = 0
		totalPushesNormalScenarios = 0
		totalPushesMergeScenarios = 0
		totalRepeatedBuilds = 0
		totalMS = 0
		totalBuilds = 0
		totalMSPassed = 0
		totalMSErrored = 0
		totalMSFailed = 0
		totalMSCanceled = 0
		
		passedConflicts = ConflictAnalysis.new()
		erroredConflicts = ConflictAnalysis.new()
		failedConflicts = ConflictAnalysis.new()
		canceledConflicts = ConflictAnalysis.new()
		
		confBuild = ConflictBuild.new(@projectPath)
		confErrored = ConflictCategoryErrored.new()
		confFailed = ConflictCategoryFailed.new()

		Dir.chdir pathResultByProject
		CSV.open(projectName.partition('/').last+"Final.csv", "w") do |csv|
 			csv << ["Status", "Type", "Commit", "ID"]
 		end
		
		projectBuild = Travis::Repository.find(projectName)
		projectBuild.each_build do |build|
			if (build != nil)
				status = confBuild.getBuildStatus(build)
				if build.pull_request
					buildTotalPull += 1
					type = "pull"
					if (status == "passed")
						buildPullPassed += 1
					elsif (status == "errored")
						buildPullErrored += 1
					elsif (status == "failed")
						buildPullFailed += 1
					else
						buildPullCanceled += 1
					end
				else
					buildTotalPush += 1
					type = "push"
					if (status == "passed")
						buildPushPassed += 1
					elsif (status == "errored")
						buildPushErrored += 1
					elsif (status == "failed")
						buildPushFailed += 1
					else
						buildPushCanceled += 1
					end
				end
				
				if (@projectMergeScenarios.include? build.commit.sha+"\n" or @projectMergeScenarios.include? build.commit.sha)					
					totalBuilds += 1

					if(builtMergeScenarios.include? build.commit.sha+"\n" or builtMergeScenarios.include? build.commit.sha)
						totalRepeatedBuilds += 1
					else
						totalPushesMergeScenarios += 1
						builtMergeScenarios.push(build.commit.sha.gsub('\\n',''))
						
						mergeCommit = mergeScenariosAnalysis(build)
						result = @gitProject.conflictScenario(mergeCommit, projectBuild, build)
						if (result)
							totalPushes += 1
							type = confBuild.typeConflict(build)
							if (status == "passed")
								confBuild.conflictAnalysisCategories(passedConflicts, type, result)
							elsif (status == "errored")
								confBuild.conflictAnalysisCategories(erroredConflicts, type, result)
								confErrored.findConflictCause(build)
							elsif (status == "failed")
								confBuild.conflictAnalysisCategories(failedConflicts, type, result)
								confFailed.findConflictCause(build)
							else
								confBuild.conflictAnalysisCategories(canceledConflicts, type, result)
							end
						else
							totalPushesNoBuilt+=1		
						end

						if (status == "passed")
							totalMSPassed += 1
						elsif (status == "errored")
							totalMSErrored += 1
						elsif (status == "failed")
							totalMSFailed += 1
						else
							totalMSCanceled += 1
						end
					end
				end
			end

 			Dir.chdir pathResultByProject
			CSV.open(projectName.partition('/').last+"Final.csv", "a+") do |csv|
				csv << [build.state, type, build.commit.sha, build.id]
			end
		end
		
		Dir.chdir pathMergeScenariosAnalysis
		CSV.open("TotalMergeScenariosFinal.csv", "a+") do |csv|
			csv << [projectName, totalPushesMergeScenarios, builtMergeScenarios.size, totalBuilds, totalRepeatedBuilds, totalMSPassed, totalMSErrored, totalMSFailed, totalMSCanceled]
		end

		Dir.chdir pathConflicsCauses
		CSV.open("CausesBuildConflicts.csv", "a+") do |csv|
			csv << [projectName, confErrored.getTotal(), confErrored.getUnvailableSymbol(), confErrored.getGitProblem(), confErrored.getRemoteError(), 
					confErrored.getCompilerError(), confErrored.getPermission(), confErrored.getOtherError()]
		end

		CSV.open("CausesTestConflicts.csv", "a+") do |csv|
			csv << [projectName, confFailed.getTotal(), confFailed.getFailed(), confFailed.getGitProblem(), confFailed.getRemoteError(), confFailed.getPermission(), 
				confFailed.getOtherError()]
		end

		Dir.chdir pathConflicstAnalysis
		CSV.open("ConflictsAnalysisFinal.csv", "a+") do |csv|
			csv << [projectName, totalPushesMergeScenarios, totalPushesNoBuilt, totalRepeatedBuilds, totalPushes, passedConflicts.getTotalPushes, passedConflicts.getTotalTravis,
					passedConflicts.getTotalTravisConf, passedConflicts.getTotalConfig, passedConflicts.getTotalConfigConf, passedConflicts.getTotalSource, passedConflicts.getTotalSourceConf,
					passedConflicts.getTotalAll, passedConflicts.getTotalAllConf, erroredConflicts.getTotalPushes, erroredConflicts.getTotalTravis,erroredConflicts.getTotalTravisConf, 
					erroredConflicts.getTotalConfig, erroredConflicts.getTotalConfigConf, erroredConflicts.getTotalSource, erroredConflicts.getTotalSourceConf,erroredConflicts.getTotalAll, 
					erroredConflicts.getTotalAllConf, failedConflicts.getTotalPushes, failedConflicts.getTotalTravis,failedConflicts.getTotalTravisConf, failedConflicts.getTotalConfig, 
					failedConflicts.getTotalConfigConf, failedConflicts.getTotalSource, failedConflicts.getTotalSourceConf,failedConflicts.getTotalAll, failedConflicts.getTotalAllConf, 
					canceledConflicts.getTotalPushes, canceledConflicts.getTotalTravis,canceledConflicts.getTotalTravisConf, canceledConflicts.getTotalConfig, canceledConflicts.getTotalConfigConf, 
					canceledConflicts.getTotalSource, canceledConflicts.getTotalSourceConf,canceledConflicts.getTotalAll, canceledConflicts.getTotalAllConf]
		end
		
		return projectName, buildTotalPush, buildPushPassed, buildPushErrored, buildPushFailed, buildPushCanceled, buildTotalPull, buildPullPassed, buildPullErrored, buildPullFailed, buildPullCanceled
	end

end