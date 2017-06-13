class FixUnavailableSymbol
  def initialize

  end

  def verfyFixPattern(filesConflictsInfo, diffErrorFix)
    index = 0
    fixPattern = []
    filesConflictsInfo.each do |fileConflictBuild|
      if (diffErrorFix[0][fileConflictBuild[0]].to_s.match(/Insert QualifiedName: [\s\S]*#{fileConflictBuild[1]}[\s\S]* into ImportDeclaration/))
        fixPattern[index] = "IMPORT-UPDATE"
      elsif (diffErrorFix[0][fileConflictBuild[0]].to_s.match(/Update SimpleName: [\s\S]*#{fileConflictBuild[1]}[\s\S]* to [\s\S]*\n/))
          fixPattern[index] = "METHOD-NAME-UPDATE"
      elsif (diffErrorFix[0][fileConflictBuild[2]].to_s.match(/Delete QualifiedName: [\s\S]*#{fileConflictBuild[1]}(\n)?/))
        fixPattern[index] = "MISSING-ELEMENT-REMOVAL"
      else
        fixPattern[index] = "OTHER"
      end
      index += 1
    end
    return fixPattern
  end
end