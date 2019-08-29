class UnavailableSymbolExtractor

	def initialize()

	end

	def extractionFilesInfo(buildLog, completeBuildLog)
		stringNotFindType = "not find: type"
		stringNotMember = "is not a member of"
		stringErro = "ERROR"
		categoryMissingSymbol = ""

		filesInformation = []
		numberOcccurrences = buildLog.scan(/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\]\,]* cannot find symbol[\n\r]+\[ERROR\]?[ \t\r\n\f]*symbol[ \t\r\n\f]*:[ \t\r\n\f]*method [a-zA-Z0-9\/\-\.\:\[\]\,\(\)]*[\n\r]+\[ERROR\]?[ \t\r\n\f]*location[ \t\r\n\f]*:[ \t\r\n\f]*class[ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,\(\)]*[\n\r]?|\[#{stringErro}\][\s\S]*#{stringNotFindType}|\[#{stringErro}\][\s\S]*#{stringNotMember}|\[ERROR\]?[\s\S]*cannot find symbol/).size
		begin
			if (buildLog[/\[ERROR\]?[\s\S]*cannot find symbol/] || buildLog[/\[ERROR\] [a-zA-Z0-9\/\-\.\:\[\]\,]* cannot find symbol[\n\r]+\[ERROR\]?[ \t\r\n\f]*symbol[ \t\r\n\f]*:[ \t\r\n\f]*method [a-zA-Z0-9\/\-\.\:\[\]\,\(\)]*[\n\r]+\[ERROR\]?[ \t\r\n\f]*location[ \t\r\n\f]*:[ \t\r\n\f]*class[ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,\(\)]*[\n\r]?/] || buildLog[/\[javac\] [\/a-zA-Z\_\-\.\:0-9 ]* cannot find symbol/])
        if (buildLog[/error: package [a-zA-Z\.]* does not exist /])
					return getInfoSecondCase(buildLog, completeBuildLog)
        elsif (buildLog[/error: cannot find symbol/])
					return getInfoThirdCase(completeBuildLog)
        else
					return getInfoDefaultCase(buildLog, completeBuildLog)
        end
      else
        extractionFilesInfoForGradle(buildLog)
      end
    rescue
			return categoryMissingSymbol, [], 0
		end
	end

	def getInfoDefaultCase(buildLog, completeBuildLog)
		classFiles = []
		methodNames = []
		callClassFiles = []
		if (buildLog[/\[javac\] [\/a-zA-Z\_\-\.\:0-9]* cannot find symbol[\s\S]* \[javac\] (location:)+/])
			methodNames = buildLog.to_enum(:scan, /\[javac\] [\/a-zA-Z\_\-\.\:0-9]* cannot find symbol[\s\S]* \[javac\] (location:)+ [a-zA-Z\. ]*/).map { Regexp.last_match }
			classFiles = buildLog.to_enum(:scan, /\[javac\] [\/a-zA-Z\_\-\.\:0-9]* cannot find symbol[\s\S]* \[javac\] (location:)+ [a-zA-Z\. ]*/).map { Regexp.last_match }
			callClassFiles = buildLog.to_enum(:scan, /\[javac\] [\/a-zA-Z\_\-\.\:0-9]* cannot find symbol[\s\S]* \[javac\] (location:)+ [a-zA-Z\. ]*/).map { Regexp.last_match }
		else
			methodNames = buildLog.to_enum(:scan, /\[ERROR\][ \t\r\n\f]*symbol[ \t\r\n\f]*:[ \t\r\n\f]*[method|class|variable|constructor|static]*[ \t\r\n\f]*[a-zA-Z0-9\(\)\.\/\,\_]*[ \t\r\n\f]*[(\[INFO\] )?\[ERROR\][ \t\r\n\f]*]?(location)?/).map { Regexp.last_match }
			classFiles = buildLog.to_enum(:scan, /\[ERROR\][ \t\r\n\f]*(location)?[ \t\r\n\f]*:[ \t\r\n\f]*(@)?[class|interface|variable instance of type|variable request of type)?|package]+[ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,\(\) ]*[\n\r]?/).map { Regexp.last_match }
			callClassFiles = getCallClassFiles(completeBuildLog)
		end
		categoryMissingSymbol = getTypeUnavailableSymbol(methodNames[0])
		filesInformation = []
		count = 0
		while (count < classFiles.size)
			#fazer chamada de categorySymbol aqui... não precisa mudar mais nada no método methodNames[count]
			methodName = methodNames[count].to_s.match(/symbol[ \t\r\n\f]*:[ \t\r\n\f]*(method|variable|class|constructor|static)[ \t\r\n\f]*[a-zA-Z0-9\_]*/)[0].split(" ").last
			classFile = classFiles[count].to_s.match(/location[ \t\r\n\f]*:[ \t\r\n\f]*(@)?(variable (request|instance) of type|class|interface|package)?[ \t\r\n\f]*[a-zA-Z0-9\/\-\.\:\[\]\,\(\) ]*/)[0].split(".").last.gsub("\r", "").to_s
			callClassFile = ""
			line = callClassFiles[count].to_s.gsub(" cannot find symbol","").to_s.split(".java")[1].to_s.match(/[0-9]*\,[0-9]*/)[0]
			if (buildLog[/\[javac\] [\/a-zA-Z\_\-\.\:0-9]* cannot find symbol[\s\S]* \[javac\] (location:)+/])
				callClassFile = classFile
			else
				callClassFile = callClassFiles[count].to_s.match(/\[ERROR\]?[ \t\r\n\f]*[\/\-\.\:a-zA-Z0-9\,\_]*/)[0].split("/").last.gsub(".java:", "").gsub("\r", "").to_s
			end
			categoryMissingSymbol = getTypeUnavailableSymbol(methodNames[count])
			count += 1
			filesInformation.push([categoryMissingSymbol, classFile, methodName, callClassFile, line])
		end
		return categoryMissingSymbol, filesInformation, filesInformation.size
  end

  def extractionFilesInfoForGradle(buildLog)
    filesInformation = []
    numberOccurrences = buildLog.scan(/[A-Za-z]*\.(java)(:)(\d+)(:)( error: )([\s\S]*)(class )([A-Za-z]*)/).size
    begin
      information = buildLog.to_enum(:scan,/[A-Za-z]*\.(java)(:)(\d+)(:)( error: )([\s\S]*)(class )([A-Za-z]*)/).map { Regexp.last_match }
      count = 0
      while(count < information.size)
        callClassFile = information[count].to_s.match(/[A-Za-z]*\.(java)/)[0].gsub('.java','')
        classFile = information[count].to_s.match(/(class )([A-Za-z]*)/)[0].gsub('class ','')
        variableName = ""
        methodName = information[count].to_s.match(/(method )([A-Za-z0-9]*)/)[0].split(" ")[1]
        categoryMissingSymbol = getTypeUnavailableSymbol(information[0])
        line = information[count].to_s.match(/(java:)\d+/)[0].gsub('java:','')
        count += 1
        if (!methodName.include? ".")
          filesInformation.push([categoryMissingSymbol, classFile, methodName, callClassFile, line])
        end
      end
      return categoryMissingSymbol, filesInformation, filesInformation.size
    rescue
      return "categoryMissingSymbol", [], 0
    end
  end


	def getInfoThirdCase(buildLog)
		filesInformation = []
		classFiles = buildLog.to_enum(:scan, /\[ERROR\][a-zA-Z0-9\/\.\: \[\]\,\-]* error: cannot find symbol/).map { Regexp.last_match }
		count = 0
		while(count < classFiles.size)
			classFile = classFiles[count].to_s.split(".java")[0].to_s.split('\/').last
			filesInformation.push(classFile)
			count += 1
		end
		if (filesInformation.size < 1)
			classFiles = buildLog.to_enum(:scan, /[a-zA-Z0-9\/\.\: \[\]\,\-]* error: cannot find symbol/).map { Regexp.last_match }
			count = 0
			while(count < classFiles.size)
				classFile = classFiles[count].to_s.split(".java")[0].to_s.split('\/').last
				filesInformation.push(["unavailableSymbolFileSpecialCase", classFile])
				count += 1
			end
		end
		return "unavailableSymbolFileSpecialCase", filesInformation, filesInformation.size
	end

	def getInfoSecondCase(buildLog, completeBuildLog)
		#classFiles = buildLog.to_enum(:scan, /\[javac\] [\/a-zA-Z\_\-\.\:0-9]* cannot find symbol[\s\S]* \[javac\] (location:)+/).map { Regexp.last_match }
		methodNames = buildLog.to_enum(:scan, /\[javac\] [\/a-zA-Z\_\-\.\:0-9]* cannot find symbol[\s\S]* \[javac\] (location:)+/).map { Regexp.last_match }
		#categoryMissingSymbol = getTypeUnavailableSymbol(methodNames[0])
		categoryMissingSymbol = getTypeUnavailableSymbol(methodNames[0])
		filesInformation = []
		methodNames = buildLog.to_enum(:scan, /error: package [a-zA-Z\.]* does not exist/).map { Regexp.last_match }
		count = 0
		while (count < methodNames.size)
			packageName = methodNames[count].to_s.split("package ").last.to_s.gsub(" does not exist")
			count += 1
			filesInformation.push([categoryMissingSymbol, packageName])
		end
		return categoryMissingSymbol, filesInformation, filesInformation.size
	end

	def getCallClassFiles(buildLog)
		if (buildLog.include?('Retrying, 3 of 3'))
			aux = buildLog[/BUILD FAILURE[\s\S]*/]
			return aux.to_s.to_enum(:scan, /\[ERROR\]?[ \t\r\n\f]*[\/\-\.\:a-zA-Z\[\]0-9\,\_]* cannot find symbol/).map { Regexp.last_match }
		elsif (buildLog.include? 'Compilation failure:')
			return buildLog[/Compilation failure:[\s\S]*/].to_enum(:scan, /\[ERROR\]?[ \t\r\n\f]*[\/\-\.\:a-zA-Z\[\]0-9\,]* cannot find symbol/).map { Regexp.last_match }
		else
			return buildLog.to_enum(:scan, /\[ERROR\]?[ \t\r\n\f]*[\/\-\.\:a-zA-Z\[\]0-9\,]* cannot find symbol/).map { Regexp.last_match }
		end
	end

	def getTypeUnavailableSymbol(methodNames)
		#update aqui - Receber um array, e retornar todos os valores possíveis
		if (methodNames.to_s.match(/symbol[ \t\r\n\f]*:[ \t\r\n\f]*(method|constructor)[ \t\r\n\f]*[a-zA-Z0-9\_]*/))
			return "unavailableSymbolMethod"
		elsif (methodNames.to_s.match(/symbol[ \t\r\n\f]*:[ \t\r\n\f]*(variable)[ \t\r\n\f]*[a-zA-Z0-9\_]*/))
			return "unavailableSymbolVariable"
		elsif (methodNames.to_s.match(/error: package/))
			return "unavailablePackage"
		else
			return "unavailableSymbolFile"
		end
	end

end

obj = UnavailableSymbolExtractor.new()
obj.extractionFilesInfo("Download https://jcenter.bintray.com/org/apache/httpcomponents/httpcore/4.4.6/httpcore-4.4.6.jar
Download https://jcenter.bintray.com/org/slf4j/slf4j-api/1.7.25/slf4j-api-1.7.25.jar
Download https://jcenter.bintray.com/org/codehaus/woodstox/stax2-api/4.2/stax2-api-4.2.jar
/home/travis/build/leusonmario/eureka/eureka-client/src/main/java/com/netflix/appinfo/AmazonInfo.java:127: error: cannot find symbol
            return getToMyString();
                   ^
  symbol:   method getToMyString()
  location: class MetaDataKey
Note: Some input files use or override a deprecated API.
Note: Recompile with -Xlint:deprecation for details.
Note: Some input files use unchecked or unsafe operations.
Note: Recompile with -Xlint:unchecked for details.
1 error
:eureka-client:compileJava FAILED
FAILURE: Build failed with an exception.
", "" )


