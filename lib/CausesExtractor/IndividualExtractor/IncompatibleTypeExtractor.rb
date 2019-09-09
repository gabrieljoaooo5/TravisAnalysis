class IncompatibleTypeExtractor

  def initialize()

  end


  def extractionFilesInfoForGradle(buildLog)
    filesInformation = []
    if (buildLog[/[A-Za-z]*\.(java)(:)(\d+)(:)( error: )([\s\S]*)( cannot be converted to )([A-Za-z]*)/])
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

    elsif (buildLog[/[A-Za-z]*\.(java)(:)(\[\d+,\d+\])( error: )(incompatible types: )([A-Za-z]*)( cannot be converted to )([A-Za-z]*)/])
      numberOccurrences = buildLog.scan(/(\[ERROR\] )(\S*)[A-Za-z0-9]*\.(java)(:)(\[\d+,\d+\])( error: )(incompatible types: )([A-Za-z]*)( cannot be converted to )([A-Za-z]*)/).size
      begin
        information = buildLog.to_enum(:scan,/(\[ERROR\] )(\S*)[A-Za-z0-9]*\.(java)(:)(\[\d+,\d+\])( error: )(incompatible types: )([A-Za-z]*)( cannot be converted to )([A-Za-z]*)/).map { Regexp.last_match }
        count = 0
        while(count < information.size)
          classFile = information[count].to_s.match(/[A-Za-z]*\.(java)/)[0].gsub('.java','')
          expectedType = information[count].to_s.match(/(cannot be converted to )([A-Za-z]*)/)[0].gsub('cannot be converted to ','')
          receivedType = information[count].to_s.match(/(types: )([A-Za-z]*)/)[0].gsub('types: ','')
          line = information[count].to_s.match(/\[\d+/)[0].gsub('[','')
          column = information[count].to_s.match(/\d+\]/)[0].gsub(']','')

          partialPath = information[count].to_s.match(/(\S*)[A-Za-z0-9]*\.(java)/).to_s.gsub((/([\s\S]*)\/(neo4j-timetree)/), 'merge')
          Dir.chdir "/home"
          pathes = %x(find -name #{classFile + ".java"})
          path_file = ""
          pathes.each_line do |truthPath|
            if truthPath.include? partialPath
              path_file = '/home' + truthPath.to_s.gsub('./', '/').gsub((/\n/), '')
            end
          end

          file = IO.readlines(path_file)
          aux = file[line.to_i - 1].to_s.match(/([A-Za-z0-9]*)((\.[\s\S]*))/)[0]
          var = aux.gsub((/(\.[\s\S]*)/),'')
          method = aux.to_s.match(/\.([A-Za-z0-9]*)(\()/).to_s.gsub((/(\.|\()/), '')
          if (numberOfAtributes = file.to_s.scan(/(#{classFile})([\s\S]*)(public|private|protected)+([a-zA-Z0-9 ]*)(#{var})/).size != 0)
            aux2 = file.to_s.match(/(#{classFile})([\s\S]*)(public|private|protected)+([a-zA-Z0-9 ]*)(#{var})/)[0].split(/\W+/)
            typeOfVar = aux2[aux2.length - 2]
          else
              typeOfVar = "Undefined type of var"
          end
          count += 1
          if (!classFile.include? ".")
            filesInformation.push(["incompatibleType", classFile, expectedType, receivedType, line, column, var, typeOfVar, method])
          end
        end
        print filesInformation
        return "incompatibleType", filesInformation, information.size
      rescue
        return "incompatibleType", [], 0
      end

     end
  end

end


file = IO.readlines("travis.txt")
obj = IncompatibleTypeExtractor.new()
obj.extractionFilesInfoForGradle(file.to_s)
