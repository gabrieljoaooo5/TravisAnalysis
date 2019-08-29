class IncompatibleTypeExtractor

  def initialize()

  end


  def extractionFilesInfoForGradle(buildLog)
    filesInformation = []
    numberOccurrences = buildLog.scan(/[A-Za-z]*\.(java)(:)(\d+)(:)( error: )([\s\S]*)( cannot be converted to )([A-Za-z]*)/).size
    begin
      information = buildLog.to_enum(:scan,/[A-Za-z]*\.(java)(:)(\d+)(:)( error: )([\s\S]*)( cannot be converted to )([A-Za-z]*)/).map { Regexp.last_match }
      count = 0
      while(count < information.size)
        classFile = information[count].to_s.match(/[A-Za-z]*\.(java)/)[0].gsub('.java','')
        expectedType = information[count].to_s.match(/(cannot be converted to )([A-Za-z]*)/)[0].gsub('cannot be converted to ','')
        receivedType = information[count].to_s.match(/(types: )([A-Za-z]*)/)[0].gsub('types: ','')
        count += 1
        if (!classFile.include? ".")
          filesInformation.push(["incompatibleType", classFile, expectedType, receivedType])
        end
      end
      return "incompatibleType", filesInformation, information.size
    rescue
      return "incompatibleType", [], 0
    end
  end

end

