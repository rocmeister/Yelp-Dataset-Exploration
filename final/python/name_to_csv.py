
import csv
import os
import os.path

def getNameGenderFreq(nameGenderFreqList, inputFile):
    with open(inputFile) as fin:
        for line in fin:
            contents = line.strip().split(',')
            nameGenderFreq = [contents[0], contents[1], contents[2]]
            nameGenderFreqList.append(nameGenderFreq)

def writeFile(outputFile):
    with open(outputFile, 'w') as fout:
        csvFile = csv.writer(fout)
        for nameGenderFreq in nameGenderFreqList:
            csvFile.writerow(list(nameGenderFreq))

def getFileNames(directoryName):
    return [os.path.join(directoryName, file) for file in os.listdir(directoryName) \
            if os.path.isfile(os.path.join(directoryName, file))]

if __name__ == '__main__':
    nameGenderFreqList = []
    for inputFile in getFileNames('./names'):
        getNameGenderFreq(nameGenderFreqList, inputFile)
    writeFile('nameGender.csv')
