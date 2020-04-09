import csv
import json

csvReader = csv.reader(open("data/processed-data/tract_county_cbsa_xwalk.csv", encoding='mac_roman', newline=''))

cbsaToCounty = {}
countyToCbsa = {}

header = next(csvReader)

# a convenience function. csvReader contains lists/arrays. Convert them to objects
# so can get values by column name. I believe row["name_of_col"] is equivilant to row$name_of_col in R
def rowToObject(rowList):
	rowObj = {}
	for i in range(0, len(rowList)):
		rowObj[header[i]] = rowList[i]
	return rowObj


for rowList in csvReader:
	row = rowToObject(rowList)
	county = row["county_fips"]
	cbsa = row["cbsa"]

	# generate a list of unique cbsas that overlap with each county
	if county not in countyToCbsa:
		countyToCbsa[county] = [cbsa]
	else:
		# I belive this code is never used, since at most each county
		# overlaps with 1 cbsa (or in some cases 0 for rural counties)
		if cbsa not in countyToCbsa[county]:
			countyToCbsa[county].append(cbsa)

	# generates a list of unique counties that overlap with each cbsa
	if cbsa not in cbsaToCounty:
		cbsaToCounty[cbsa] = [county] 
	else:
		# this code is used, so some cbsa's contain many counties (up to 29)
		if county not in cbsaToCounty[cbsa]:
			cbsaToCounty[cbsa].append(county)



#############################################this code not needed for production
# Just curious what the spread of counties per cbsa looks like
countiesPerCbsa = {}
for cbsa in cbsaToCounty:
	countyCount = len(cbsaToCounty[cbsa])
	if cbsa != "NA":
		if countyCount not in countiesPerCbsa:
			countiesPerCbsa[countyCount] = 1
		else:
			countiesPerCbsa[countyCount] += 1

# Just was curious. Atlanta cbsa contains 29 counties
# NYC cbsa contains 25 counties
# 616 cbsas only contain 1 county

print(countiesPerCbsa)
############################################# end not needed for production



#write to json files
with open('data/processed-data/cbsaToCounty.json', 'w') as f:
	json.dump(cbsaToCounty, f)

with open('data/processed-data/countyToCbsa.json', 'w') as f:
	json.dump(countyToCbsa, f)
