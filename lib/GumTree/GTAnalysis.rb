require 'nokogiri'
require 'open-uri'
require 'rest-client'
require 'require_all'
require 'net/http'
require 'json'
require 'uri'
require_all './Repository'

class GTAnalysis
	def initialize(gumTreePath)
		@mergeCommit = MergeCommit.new()
		@gumTreePath = gumTreePath
	end

	def getGumTreePath()
		@gumTreePath
	end

	def getGumTreeAnalysis(pathProject, build, conflictCauses)
		parents = @mergeCommit.getParentsMergeIfTrue(pathProject, build.commit.sha)
		actualPath = Dir.pwd
		
		pathCopies = createCopyProject(build.commit.sha, parents, pathProject)

		Dir.chdir getGumTreePath()
		#passar como parametro o path copies
		#  		   result 			left 		right 		MergeCommit 	parent1 	parent2 	problemas
		out = gumTreeDiffByBranch(pathCopies[1], pathCopies[2], pathCopies[3], pathCopies[4], conflictCauses)
		deleteProjectCopies(pathCopies)
		Dir.chdir actualPath
		return out
	end

	def createDirectories(pathProject)
		copyBranch = []
		Dir.chdir pathProject
		Dir.chdir ".."
		FileUtils::mkdir_p 'Copies/Result'
		FileUtils::mkdir_p 'Copies/Left'
		FileUtils::mkdir_p 'Copies/Right'
		FileUtils::mkdir_p 'Copies/Base'		
		Dir.chdir "Copies"
		copyBranch.push(Dir.pwd)
		Dir.chdir "Result"
		copyBranch.push(Dir.pwd)
		Dir.chdir copyBranch[0]
		Dir.chdir "Left"
		copyBranch.push(Dir.pwd)
		Dir.chdir copyBranch[0]
		Dir.chdir "Right"
		copyBranch.push(Dir.pwd)
		Dir.chdir copyBranch[0]
		Dir.chdir "Base"
		copyBranch.push(Dir.pwd)
		return copyBranch
	end
	
	def createCopyProject(mergeCommit, parents, pathProject)
		copyBranch = createDirectories(pathProject)
		Dir.chdir pathProject
		checkout = %x(git checkout master > /dev/null 2>&1)
		base = %x(git merge-base --all #{parents[0]} #{parents[1]})
		checkout = %x(git checkout #{base} > /dev/null 2>&1)
		clone = %x(cp -R #{pathProject} #{copyBranch[4]})
		invalidFiles = %x(find #{copyBranch[4]} -type f -regextype posix-extended -iregex '.*\.(sh|md|yaml|yml|conf|scala|properties|less|txt|gitignore)$' -delete)
		invalidFiles = %x(find #{copyBranch[4]} -type f  ! -name "*.?*" -delete)
		checkout = %x(git checkout #{mergeCommit} > /dev/null 2>&1)
		clone = %x(cp -R #{pathProject} #{copyBranch[1]})
		invalidFiles = %x(find #{copyBranch[1]} -type f -regextype posix-extended -iregex '.*\.(sh|md|yaml|yml|conf|scala|properties|less|txt|gitignore)$' -delete)
		invalidFiles = %x(find #{copyBranch[4]} -type f  ! -name "*.?*" -delete)
		
		index = 0
		while(index < parents.size)
			checkout = %x(git checkout #{parents[index]} > /dev/null 2>&1)
			clone = %x(cp -R #{pathProject} #{copyBranch[index+2]} > /dev/null 2>&1)
			invalidFiles = %x(find #{copyBranch[index+2]} -type f -regextype posix-extended -iregex '.*\.(sh|md|yaml|yml|conf|scala|properties|less|txt|gitignore)$' -delete)
			invalidFiles = %x(find #{copyBranch[index+2]} -type f  ! -name "*.?*" -delete)
			checkout = %x(git checkout master > /dev/null 2>&1)
			index += 1
		end

		return copyBranch[0], copyBranch[1], copyBranch[2], copyBranch[3], copyBranch[4], mergeCommit
		#      copies         result 			left 		right 			base			mergeCommit
	end

	def deleteProjectCopies(pathCopies)
		index = 0
		while(index < pathCopies.size)
			delete = %x(rm -rf #{pathCopies[index]})	
			index += 1
		end
	end

	def runAllDiff(firstBranch, secondBranch)
		Dir.chdir @gumTreePath
		mainDiff = nil
		modifiedFilesDiff = []
		addedFiles = []
		deletedFiles = []
		begin
			thr = Thread.new { diff = system "bash", "-c", "exec -a gumtree ./gumtree webdiff #{firstBranch.gsub("\n","")} #{secondBranch.gsub("\n","")}" }
			sleep(10)
			mainDiff = %x(wget http://127.0.0.1:4754/ -q -O -)
			modifiedFilesDiff = getDiffByModification(mainDiff[/Modified files \((.*?)\)/m, 1])
			addedFiles = getDiffByAddedFile(mainDiff[/Added files \((.*?)\)/m, 1])
			deletedFiles = getDiffByDeletedFile(mainDiff[/Deleted files \((.*?)\)/m, 1])
			
			kill = %x(pkill -f gumtree)
			sleep(5)
		rescue Exception => e
			puts "GumTree Failed"
		end
		return modifiedFilesDiff, addedFiles, deletedFiles
	end

	def gumTreeDiffByBranch(result, left, right, base, conflictCauses)
		baseLeft = runAllDiff(base, left)
		baseRight = runAllDiff(base, right)
		leftResult = runAllDiff(left, result)
		rightResult = runAllDiff(right, result)
		# passar como parametro o caminho dos diretorios (base, left, right, result). Por enquanto apenas o left e right
		return verifyModificationStatus(baseLeft, leftResult, baseRight, rightResult, conflictCauses, left, right)
	end

	def verifyModificationStatus(baseLeft, leftResult, baseRight, rightResult, conflictCauses, leftPath, rightPath)
		statusModified = verifyModifiedFile(baseLeft[0], leftResult[0], baseRight[0], rightResult[0])
		statusAdded = verifyAddedDeletedFile(baseLeft[1], leftResult[1], baseRight[1], rightResult[1])
		statusDeleted = verifyAddedDeletedFile(baseLeft[2], leftResult[2], baseRight[2], rightResult[2])
		
		conflictingContributions = []
		allIntegratedContributions = false
		if (statusModified and statusAdded and statusDeleted)
			#IT WAS LOVE (COMMIT WITHOUT MERGE CONFLICTS), IT WAS NOT A PERFECT ILLUSION
			allIntegratedContributions = true
			indexValue = 0
			conflictCauses.getCausesConflict().each do |conflictCause|
				if(conflictCause == "unimplementedMethod")
					if (verifyBuildConflictByUnimplementedMethod(baseLeft[0], leftResult[0], baseRight[0], rightResult[0], conflictCauses.getFilesConflict()[indexValue]) == false)
						conflictingContributions[indexValue] = false
						#return false, true
					end
				elsif (conflictCause == "unavailableSymbol")
					if (verifyBuildConflictByUnavailableSymbol(baseLeft, leftResult, baseRight, rightResult, conflictCauses.getFilesConflict()[indexValue], leftPath, rightPath) == false)
						conflictingContributions[indexValue] = false
						#return false, true
					end
				elsif (conflictCause == "statementDuplication")
					if (verifyBuildConflictByStatementDuplication(baseLeft, leftResult, baseRight, rightResult, conflictCauses.getFilesConflict()[indexValue]) == false)
						conflictingContributions[indexValue] = false
						#return false, true
					end
				elsif (conflictCause == "methodUpdate")
					if (verifyBuildConflictByMethodUpdate(leftPath, rightPath, conflictCauses.getFilesConflict()[indexValue]) == false)
						conflictingContributions[indexValue] = false
						#return false, true
					end
				elsif (conflictCause == "dependencyProblem")
					if ((verifyBuildConflictByDependency(baseLeft[0], leftResult[0], baseRight[0], rightResult[0], conflictCauses.getFilesConflict()[indexValue]) == true))
						conflictingContributions[indexValue] = false
						#return false, true
					end
				end
				conflictingContributions[indexValue] = true
				indexValue += 1
			end
			#return true, true
		else 
			#IT WAS NOT LOVE (COMMIT WITH MERGE CONFLICTS), IT WAS A PERFECT ILLUSION
			indexValue = 0
			conflictCauses.getCausesConflict().each do |conflictCause|
				if(conflictCause == "unimplementedMethod")
					if (verifyBuildConflictByUnimplementedMethod(baseLeft[0], leftResult[0], baseRight[0], rightResult[0], conflictCauses.getFilesConflict()[indexValue]) == false)
						conflictingContributions[indexValue] = false
						#return false, false
					end
				elsif (conflictCause == "unavailableSymbol")
					if (verifyBuildConflictByUnavailableSymbol(baseLeft, leftResult, baseRight, rightResult, conflictCauses.getFilesConflict()[indexValue], leftPath, rightPath) == false)
						conflictingContributions[indexValue] = false
						#return false, false
					end
				elsif (conflictCause == "statementDuplication")
					if (verifyBuildConflictByStatementDuplication(baseLeft, leftResult, baseRight, rightResult, conflictCauses.getFilesConflict()[indexValue]) == false)
						conflictingContributions[indexValue] = false
						#return false, false
					end
				elsif (conflictCause == "methodUpdate")
					if (verifyBuildConflictByMethodUpdate(leftPath, rightPath, conflictCauses.getFilesConflict()[indexValue]) == false)
						conflictingContributions[indexValue] = false
						#return false, false
					end
				elsif (conflictCause == "dependencyProblem")
					if ((verifyBuildConflictByDependency(baseLeft[0], leftResult[0], baseRight[0], rightResult[0], conflictCauses.getFilesConflict()[indexValue]) == true))
						conflictingContributions[indexValue] = false
						#return false, false
					end
				end
				conflictingContributions[indexValue] = true
				indexValue += 1
			end
			#return true, false
		end
		return conflictingContributions, allIntegratedContributions
		#return false, nil
	end

	def verifyBuildConflictByMethodUpdate (leftPath, rightPath, filesConflicting)
		count = 0
		while (count < filesConflicting.size)
			leftPathMethods = []
			rightPathMethods = []
			if (filesConflicting[0][3] == "method")
				leftPathMethods = getParametersListSizeForMethod(leftPath, filesConflicting[0][2], filesConflicting[0][1])
				rightPathMethods = getParametersListSizeForMethod(rightPath, filesConflicting[0][2], filesConflicting[0][1])
			elsif (filesConflicting[0][3] == "constructor")
				leftPathMethods = getParametersListSizeForConstructor(leftPath, filesConflicting[0][2], filesConflicting[0][1])
				rightPathMethods = getParametersListSizeForConstructor(rightPath, filesConflicting[0][2], filesConflicting[0][1])
			end
			if (leftPathMethods[0].size != rightPathMethods[0].size)
				return true
			else
				equalParametersNumber = 0
				leftPathMethods[1].each do |leftMethod|
				    rightPathMethods[1].each do |rightMethod|
				        if (leftMethod.size == rightMethod.size)
				            if (leftMethod == rightMethod)
				                equalParametersNumber += 1
				            end
				        end
				    end
				end
				if (leftPathMethods[0].size == equalParametersNumber)
					return false
				end
			end
			count += 1
		end
		return true
	end

	def verifyBuildConflictByStatementDuplication(baseLeft, leftResult, baseRight, rightResult, filesConflicting)
		count = 0
		while(count < filesConflicting.size)
			if(leftResult[0][filesConflicting[count][0]] != nil and leftResult[0][filesConflicting[count][0]].to_s.match(/Insert SimpleName: #{filesConflicting[count][2]}[0-9\(\)]* into [a-zA-Z]*[0-9\(\)]*/))
				internalCount = 0
				methodOccurence = leftResult[0][filesConflicting[count][0]].to_s.to_enum(:scan, /Insert SimpleName: #{filesConflicting[count][2]}[0-9\(\)]* into [a-zA-Z]*[0-9\(\)]*/).map { Regexp.last_match }
				while(internalCount < methodOccurence.size)
					nodeMethod = methodOccurence[count].to_s.split("(").last.gsub(')','')
					if (!leftResult[0][filesConflicting[count][0]].to_s.match(/Insert SimpleName: #{filesConflicting[count][1]}[0-9\(\)]* into [a-zA-Z]*\(#{nodeMethod}\)/))
						return false
					end
					internalCount += 1
				end
				if(rightResult[0][filesConflicting[count][0]].to_s.match(/Insert SimpleName: #{filesConflicting[count][1]}[0-9\(\)]* into [a-zA-Z]*[0-9\(\)]*/))
					return true
				end
			end
			if(rightResult[0][filesConflicting[count][0]] != nil and rightResult[0][filesConflicting[count][0]].to_s.match(/Insert SimpleName: #{filesConflicting[count][2]}[0-9\(\)]* into [a-zA-Z]*[0-9\(\)]*/))
				internalCount = 0
				methodOccurence = rightResult[0][filesConflicting[count][0]].to_s.to_enum(:scan, /Insert SimpleName: #{filesConflicting[count][2]}[0-9\(\)]* into [a-zA-Z]*[0-9\(\)]*/).map { Regexp.last_match }
				while(internalCount < methodOccurence.size)
					nodeMethod = methodOccurence[count].to_s.split("(").last.gsub(')','')
					if (!rightResult[0][filesConflicting[count][0]].to_s.match(/Insert SimpleName: #{filesConflicting[count][1]}[0-9\(\)]* into [a-zA-Z]*\(#{nodeMethod}\)/))
						return false
					end
					internalCount += 1
				end
				if(leftResult[0][filesConflicting[count][0]].to_s.match(/Insert SimpleName: #{filesConflicting[count][1]}[0-9\(\)]* into [a-zA-Z]*[0-9\(\)]*/))
					return true
				end
			end
			count += 1
		end
	end

	def verifyBuildConflictByUnavailableSymbol (baseLeft, leftResult, baseRight, rightResult, filesConflicting, leftPath, rightPath)
		count = 0
		while(count < filesConflicting.size)
			if(leftResult[0][filesConflicting[count][0]] != nil and leftResult[0][filesConflicting[count][0]].to_s.match(/Delete SimpleName: #{filesConflicting[count][1]}[\s\S]*[\n\r]?|Update SimpleName: #{filesConflicting[count][1]}[\s\S]*[\n\r]?/))
				if (rightResult[0][filesConflicting[count][2]] != nil and rightResult[0][filesConflicting[count][2]].to_s.match(/Insert (SimpleName|QualifiedName): [a-zA-Z\.]*?#{filesConflicting[count][1]}[\s\S]*[\n\r]?/))
					return true
				else
					baseLeft[1].each do |item|
						if (item.include?(filesConflicting[count][2].to_s))
							return true
						end
					end

					if (rightResult[0][filesConflicting[count][2]] == nil)
						return true
					end
				end
			end
			if(rightResult[0][filesConflicting[count][0]] != nil and rightResult[0][filesConflicting[count][0]].to_s.match(/Delete SimpleName: #{filesConflicting[count][1]}[\s\S]*[\n\r]?|Update SimpleName: #{filesConflicting[count][1]}[\s\S]*[\n\r]?/))
				if(leftResult[0][filesConflicting[count][2]] != nil and leftResult[0][filesConflicting[count][2]].to_s.match(/Insert (SimpleName|QualifiedName): [a-zA-Z\.]*?#{filesConflicting[count][1]}[\s\S]*[\n\r]?/))
					return true
				else
					rightResult[1].each do |item|
						if (item.include?(filesConflicting[count][2].to_s))
							return true
						end
					end

					if (leftResult[0][filesConflicting[count][2]] == nil)
						return true
					end
				end
			end
			Dir.chdir leftPath
			pathFileLeft = %x(find -name #{filesConflicting[count][1]+".java"})
			Dir.chdir rightPath
			pathFileRight = %x(find -name #{filesConflicting[count][1]+".java"})
			if (pathFileLeft != pathFileRight)
				return true
			end
			count += 1
		end
		return false
	end

	def verifyBuildConflictByUnimplementedMethod(baseLeft, leftResult, baseRight, rightResult, filesConflicting)
		count = 0
		while (count < filesConflicting.size)
			if(baseLeft[filesConflicting[count][1]] != nil and baseLeft[filesConflicting[count][1].to_s].to_s.match(/Insert SimpleName: #{filesConflicting[count][2].to_s.gsub(/\(.*/, '').gsub('(', '')}[\(\)0-9]* into MethodDeclaration[\(\)0-9]* at [0-9]*/) or baseLeft[filesConflicting[count][1].to_s].to_s.match(/Update SimpleName: [\s\S]* to #{filesConflicting[count][2].gsub(/\(.*/, '').gsub('(', '')}/))
				if ((rightResult[filesConflicting[count][1]].to_s.match(/Insert SimpleName: #{filesConflicting[count][2].to_s.gsub(/\(.*/, '').gsub('(', '')}[\(\)0-9]* into MethodDeclaration[\(\)0-9]* at [0-9]*/) or rightResult[filesConflicting[count][1].to_s].to_s.match(/Update SimpleName: [\s\S]* to #{filesConflicting[count][2].gsub(/\(.*/, '').gsub('(', '')}/)) and (rightResult[filesConflicting[count][0].to_s].to_s.match(/Insert SimpleType: #{filesConflicting[count][1].gsub(/\(.*/, '').gsub('(', '')}[0-9\(\)]* into TypeDeclaration[0-9\(\)]*/)) and (!rightResult[filesConflicting[count][0].to_s].to_s.match(/Insert SimpleName: #{filesConflicting[count][2].gsub(/\(.*/, '').gsub('(', '')}[\(\)0-9]* into MethodDeclaration[\(\)0-9]* at [0-9]*/) or !rightResult[filesConflicting[count][0].to_s].to_s.match(/Update SimpleName: [\s\S]* to #{filesConflicting[count][2].gsub(/\(.*/, '').gsub('(', '')}/)))
					#BUILD CONFLICT DETECTED
					return true
				end
			end
			if(baseRight[filesConflicting[count][1]] != nil and baseRight[filesConflicting[count][1]].to_s.match(/Insert SimpleName: #{filesConflicting[count][2].to_s.gsub(/\(.*/, '').gsub('(', '')}[\(\)0-9]* into MethodDeclaration[\(\)0-9]* at [0-9]*/) or baseRight[filesConflicting[count][1].to_s].to_s.match(/Update SimpleName: [\s\S]* to #{filesConflicting[count][2].gsub(/\(.*/, '').gsub('(', '')}/))
				if ((leftResult[filesConflicting[count][1]].to_s.match(/Insert SimpleName: #{filesConflicting[count][2].to_s.gsub(/\(.*/, '').gsub('(', '')}[\(\)0-9]* into MethodDeclaration[\(\)0-9]* at [0-9]*/) or leftResult[filesConflicting[count][1].to_s].to_s.match(/Update SimpleName: [\s\S]* to #{filesConflicting[count][2].gsub(/\(.*/, '').gsub('(', '')}/)) and (leftResult[filesConflicting[count][0].to_s].to_s.match(/Insert SimpleType: #{filesConflicting[count][1].gsub(/\(.*/, '').gsub('(', '')}[0-9\(\)]* into TypeDeclaration[0-9\(\)]*/)) and (!leftResult[filesConflicting[count][0].to_s].to_s.match(/Insert SimpleName: #{filesConflicting[count][2].gsub(/\(.*/, '').gsub('(', '')}[\(\)0-9]* into MethodDeclaration[\(\)0-9]* at [0-9]*/) or !leftResult[filesConflicting[count][0].to_s].to_s.match(/Update SimpleName: [\s\S]* to #{filesConflicting[count][2].gsub(/\(.*/, '').gsub('(', '')}/)))
					#BUILD CONFLICT DETECTED"
					return true
				end
			end
			count += 1
		end
		return false
	end

	def verifyBuildConflictByDependency (baseLeft, leftResult, baseRight, rightResult, filesConflicting)
		begin
			version = filesConflicting[3].to_s.match(/[0-9\.]*/)
			if ((baseLeft["pom.xml"] == rightResult["pom.xml"] and baseRight["pom.xml"] == leftResult["pom.xml"]) or (baseLeft["pom.xml"] != nil and baseRight["pom.xml"] != nil))
				urlMavenRep = "http://search.maven.org/solrsearch/select?q=g:#{filesConflicting[0]}%20AND%20a:#{filesConflicting[1]}%20AND%20v:#{version}%20AND%20p:#{filesConflicting[2]}&rows=20&wt=json"
				uriMavenRep = URI.parse(URI.encode(urlMavenRep.strip))
				req = Net::HTTP::Get.new(urlMavenRep.to_s)
				res = Net::HTTP.start(uriMavenRep.host, uriMavenRep.port) {|http|
				  http.request(req)
				}

				conflicting = false
				jsonResultReq = JSON.parse(res.body)
				aux = 1
				jsonResultReq.each do |result|
					if (aux == 2)
						if (result[1]["numFound"] > 0)
							result[1]["docs"].each do |algo|
								if (algo["a"]==artifactID and algo["v"]==version)
									conflicting = true
								end
							end
						end
					end
					aux += 1
				end
				return conflicting
			end
		rescue
			return false
		end
		return false
	end

	def verifyAddedDeletedFile(baseLeftInitial, leftResultFinal, baseRightInitial, rightResultFinal)
		if(baseLeftInitial.size > 0) 
			baseLeftInitial.each do |fileLeft|
				if (!rightResultFinal.include?(fileLeft))
					return false
				end
			end
		end
		if (baseRightInitial.size > 0)
			baseRightInitial.each do |fileLeft|
				if (!leftResultFinal.include?(fileLeft))
					return false
				end
			end
		end
		return true
	end

	def verifyModifiedFile(baseLeftInitial, leftResultFinal, baseRightInitial, rightResultFinal)
		if(baseLeftInitial.size > 0)
			baseLeftInitial.each do |keyFile, fileLeft|
				fileRight = rightResultFinal[keyFile]
				if (fileRight == nil or fileLeft != fileRight)
					return false
				end
			end
		end
		if(baseRightInitial.size > 0) 
			baseRightInitial.each do |keyFile, fileRight|
				fileLeft = leftResultFinal[keyFile]
				if (fileLeft == nil or fileRight != fileLeft)
					return false
				end
			end
		end
		return true
	end

	def getDiffByModification(numberOcorrences)
		index = 0
		result = Hash.new()
		while(index < numberOcorrences.to_i)
			gumTreePage = Nokogiri::HTML(RestClient.get("http://127.0.0.1:4754/script?id=#{index}"))
			file = gumTreePage.css('div.col-lg-12 h3 small').text[/(.*?) \-\>/m, 1].gsub(".java", "")
			script = gumTreePage.css('div.col-lg-12 pre').text
			result[file.to_s] = script.gsub('"', "\"")
			index += 1
		end
		return result
	end

	def getDiffByDeletedFile(numberOcorrences)
		index = 0
		result = []
		while(index < numberOcorrences.to_i)
			gumTreePage = Nokogiri::HTML(RestClient.get("http://127.0.0.1:4754/"))
			gumTreePage.css('div#collapse-deleted-files table tr td').each do |element|
				result.push(element.text)
			end
			index += 1
		end
		return result
	end

	def getDiffByAddedFile(numberOcorrences)
		index = 0
		result = []
		while(index < numberOcorrences.to_i)
			gumTreePage = Nokogiri::HTML(RestClient.get("http://127.0.0.1:4754/"))
			gumTreePage.css('div#collapse-added-files table tr td').each do |element|
				result.push(element.text)
			end
			index += 1
		end
		return result
	end

	def getParametersListSizeForMethod(pathBranch, fileName, methodName)
		actualPath = Dir.pwd
        Dir.chdir pathBranch

        pathFile = %x(find -name #{fileName+".java"})
        newPathFile = %x(readlink -f #{pathFile})
        Dir.chdir getGumTreePath()
        data = %x(./gumtree parse #{newPathFile})
        stringJson = JSON.parse(data)

        countMethod = []
        typeVariableAllMethods = []
        variableDeclaration = 0
        indexMethodID = 0
        stringJson["root"]["children"].each do |child|
        	typeVariableMethod = []
            child["children"].each do |newChild|
                if (newChild["typeLabel"] == "MethodDeclaration")
                    aux = false
                    newChild["children"].each do |methodDeclaration|
                        if (methodDeclaration["label"] == methodName)
                            variableDeclaration = true
                        end

                        if (variableDeclaration == true and methodDeclaration["typeLabel"] == "SingleVariableDeclaration")
                            if (countMethod[indexMethodID] != nil)
                                countMethod[indexMethodID] = countMethod[indexMethodID] + 1
                            else
                                countMethod[indexMethodID] = 0 + 1
                            end
                            typeVariableMethod[indexMethodID] = methodDeclaration["children"][0]["label"]
                        end

                        if (variableDeclaration == true and methodDeclaration["typeLabel"] == "Block")
                            indexMethodID += 1
                            variableDeclaration = false
                        end
                    end
                    if (typeVariableMethod.size > 0)
                    	typeVariableAllMethods[indexMethodID-1] = typeVariableMethod
                    end
                    typeVariableMethod = []
                end
            end
        end
        Dir.chdir actualPath
        return countMethod, typeVariableAllMethods
    end

    def getParametersListSizeForConstructor(pathBranch, fileName, methodName)
		actualPath = Dir.pwd
        Dir.chdir pathBranch
        
        pathFile = %x(find -name #{fileName+".java"})
        newPathFile = %x(readlink -f #{pathFile})
        Dir.chdir getGumTreePath()
        data = %x(./gumtree parse #{newPathFile})
        stringJson = JSON.parse(data)

        countMethod = []
        typeVariableAllMethods = []
        variableDeclaration = 0
        indexMethodID = 0
        stringJson["root"]["children"].each do |child|
        	typeVariableMethod = []
            child["children"].each do |newChild|
                if (newChild["typeLabel"] == "MethodDeclaration")
                    aux = false
                    newChild["children"].each do |methodDeclaration|
                        if (methodDeclaration["label"] == methodName and methodDeclaration["type"] == "42")
                            variableDeclaration = true
                        end

                        if (variableDeclaration == true and methodDeclaration["typeLabel"] == "SingleVariableDeclaration")
                            if (countMethod[indexMethodID] != nil)
                                countMethod[indexMethodID] = countMethod[indexMethodID] + 1
                            else
                                countMethod[indexMethodID] = 0 + 1
                            end
                            typeVariableMethod.push(methodDeclaration["children"][0]["label"])
                        end

                        if (variableDeclaration == true and methodDeclaration["typeLabel"] == "Block")
                            indexMethodID += 1
                            variableDeclaration = false
                        end
                    end
                    if (typeVariableMethod.size > 0)
                    	typeVariableAllMethods[indexMethodID-1] = typeVariableMethod
                    end
                    typeVariableMethod = []
                end
            end
        end
        Dir.chdir actualPath
        return countMethod, typeVariableAllMethods
    end

end