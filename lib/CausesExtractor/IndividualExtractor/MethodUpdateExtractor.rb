class MethodUpdateExtractor

	def initialize()

	end

	def extractionFilesInfo(buildLog)
		filesInformation = []
		numberOccurrences = 0
		begin
			if (buildLog[/BUILD FAILURE[\s\S]*/].to_s[/\[ERROR\][ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\, ]* no suitable method found for [a-zA-Z0-9\/\-\.\:\[\]\,]*/])
				numberOccurrences = buildLog.scan(/\[ERROR\][ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\, ]* no suitable method found for [a-zA-Z0-9\/\-\.\:\[\]\,]*/).size
				changedClasses = buildLog[/BUILD FAILURE[\s\S]*/].to_s.to_enum(:scan, /\[ERROR\][ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\, ]* no suitable method found for [a-zA-Z0-9\/\-\.\:\[\]\,]*/).map { Regexp.last_match }
				callClassFiles = buildLog.to_enum(:scan, /\[ERROR\] method [ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,]*[ \t\r\n\f]*/).map { Regexp.last_match }
				count = 0
				while (count < changedClasses.size)
					changedClass = changedClasses[count].to_s.match(/\[ERROR\][ \t\r\n\f]*[a-zA-Z0-9\/\-\.\,]*/)[0].split("/").last.gsub('.java','')
					aux = callClassFiles[count].to_s.match(/\[ERROR\][ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,]*[ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,]*/)[0].split("method").last
					methodName = aux.split('.').last
					callClassFile = aux.split('.'+methodName).last.split('.').last
					filesInformation.push([changedClass, methodName, callClassFile, "method"])
					count += 1
				end
			end
			if (buildLog[/\[ERROR\][ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,\(\) ]* cannot be applied to [a-zA-Z0-9\/\-\.\:\[\]\,]*/])
				numberOccurrences = buildLog.scan(/\[ERROR\][ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,\(\) ]* cannot be applied to [a-zA-Z0-9\/\-\.\:\[\]\,]*/).size
				changedClasses = buildLog[/BUILD FAILURE[\s\S]*/].to_s.to_enum(:scan, /\[ERROR\][ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,\(\) ]* cannot be applied to [a-zA-Z0-9\/\-\.\:\[\]\,]*/).map { Regexp.last_match }
				if (changedClasses.size == 0)
					changedClasses = buildLog.to_s.to_enum(:scan, /\[ERROR\][ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,\(\) ]* cannot be applied to [a-zA-Z0-9\/\-\.\:\[\]\,]*/).map { Regexp.last_match }
				end
				count = 0
				while (count < changedClasses.size)
					changedClass = changedClasses[count].to_s.match(/\[ERROR\][ \t\r\n\f]*[a-zA-Z0-9\/\-\.\,]*/)[0].split("/").last.gsub('.java','')
				    aux = changedClasses[count].to_s.match(/\[ERROR\][ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,]*[ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,\(\) ]* cannot be applied to/)[0].split("method").last
				    callClassFile = aux.split('.').last.gsub(' cannot be applied to', '')
						methodName = ""
						if (callClassFile.include? " ")
							callClassFile = aux.split(' in class ').to_s.gsub('cannot be applied to', '').gsub(' ','')
							methodName = aux.split('method ').last.match(/[a-zA-Z]*/)
							filesInformation.push([callClassFile.split(',').last.to_s.gsub("\]",'').to_s.gsub(' ',''), callClassFile.split(',').first.to_s.gsub("\[",'').to_s.gsub(' ',''), changedClass, "method"])
						else
							methodName = aux.split('] ').last.match(/[a-zA-Z]*/)
							filesInformation.push([changedClass, methodName, changedClass, "method"])
						end
					count += 1
				end
			end
			if (buildLog[/\[ERROR\] \(actual and formal argument lists differ in length\)/])
				numberOccurrences = buildLog.scan(/\[ERROR\] \(actual and formal argument lists differ in length\)/).size
				changedClasses = buildLog[/BUILD FAILURE[\s\S]*/].to_s.to_enum(:scan, /no suitable constructor found for [a-zA-Z]*/).map { Regexp.last_match }
				count = 0
				while (count < changedClasses.size)
					changedClass = changedClasses[count].to_s.split("no suitable constructor found for ").last
				   	filesInformation.push([changedClass, changedClass, changedClass, "constructor"])
					count += 1
				end
			end
			return "methodParameterListSize", filesInformation, changedClasses.size
		rescue
			return "methodParameterListSize", [], 0
		end
	end
	
end