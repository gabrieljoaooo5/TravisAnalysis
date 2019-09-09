class BCIncompatibleType

  def initialize()

  end

  def verifyBuildConflict(info)
    count = 0
    while (count < info.size)
      classFile = info[count][1]
      receivedType = info[count][2]
      expectedType = info[count][3]
      var = info[count][6]
      typeOfVar = info[count][7]
      method = info[count][8]

      classFileBaseLeft = IO.readlines(classFile + "BaseLeft.txt")
      classFileBaseRight = IO.readlines(classFile + "BaseRight.txt")
      leftNewMethodCalls = classFileBaseLeft.to_s.scan(/(Insert SimpleName: )(#{method})/).size
      rightNewMethodCalls = classFileBaseRight.to_s.scan(/(Insert SimpleName: )(#{method})/).size
      if (leftNewMethodCalls != 0 and typeOfVar != "Undefined type of var")

        typeVarFileBaseRight = IO.readlines(typeOfVar + 'BaseRight.txt')

        rightUpdateMethod = typeVarFileBaseRight.to_s.scan(/(Update SimpleType: )([A-Za-z0-9]*)(\(\d+\))( to #{receivedType} on Method #{method})(\\n)/).size

        if rightUpdateMethod != 0
          return true #Conflito detectado, houve chamadas do método no Left e no right, o tipo do método foi alterado
        end

      end
      count +=1
    end

    return false

  end

end
