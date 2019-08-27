class StatementDuplicationExtractor

	def initialize()

	end

	def extractionFilesInfo(buildLog)
		#buildLog = build.match(/[\s\S]* BUILD FAILURE/)
		filesInformation = []
		numberOccurrences = buildLog.scan(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\]\,\(\)\s\<\>]* is already defined in [a-zA-Z0-9\/\-\.\:\[\]\,\_]* [a-zA-Z0-9]*/).size
		begin
			information = buildLog.to_enum(:scan, /\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\]\,\(\)\s\<\>]* is already defined in [a-zA-Z0-9\/\-\.\:\[\]\,\_]* [a-zA-Z0-9]*/).map { Regexp.last_match }
			count = 0
			while(count < information.size)
				classFile = information[count].to_s.match(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\]\,\s\<\>]*.java:/)[0].split("/").last.gsub('.java:','')
				variableName = ""
				if (information[count].to_s.match(/variable/) and information[count].to_s.match(/defined in method/))
					variableName = information[count].to_s.match(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\,]*\]\s[a-zA-Z0-9\/\-\_]* [a-zA-Z0-9]*/)[0].split(" ").last
				else
					variableName = "method"
				end
				methodName = information[count].to_s.match(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\,\]\s\_]*/)[0].split(" ").last
				count += 1
				if (!methodName.include? ".")
					filesInformation.push(["statementDuplication", classFile, variableName, methodName])
				end
			end
			return "statementDuplication", filesInformation, information.size
		rescue
			return "statementDuplication", [], 0
		end
	end


	def extractionFilesInfoForGradle(buildLog)
		filesInformation = []
		numberOccurrences = buildLog.scan(/[A-Za-z]*\.(java)(:)(\d+)(:)( error: )([a-z]*)( )([A-Za-z0-9]*)/).size
		begin
			information = buildLog.to_enum(:scan,/[A-Za-z]*\.(java)(:)(\d+)(:)( error: )([a-z]*)( )([A-Za-z0-9]*)/).map { Regexp.last_match }
			count = 0
			while(count < information.size)
				classFile = information[count].to_s.match(/[A-Za-z]*\.(java)/)[0]
				variableName = ""
				if (information[count].to_s.match(/variable/) and information[count].to_s.match(/defined in method/))
					variableName = information[count].to_s.match(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\,]*\]\s[a-zA-Z0-9\/\-\_]* [a-zA-Z0-9]*/)[0].split(" ").last
				else
					variableName = "method"
				end
				methodName = information[count].to_s.match(/(method )([A-Za-z0-9]*)/)[0].split(" ")[1]
				count += 1
				if (!methodName.include? ".")
					filesInformation.push(["statementDuplication", classFile, variableName, methodName])
				end
			end
			return "statementDuplication", filesInformation, information.size
		rescue
			return "statementDuplication", [], 0
		end
	end

end

