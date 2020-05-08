import webbrowser, os
import json
import boto3
import io
import csv as cv
from io import BytesIO
import sys
from pprint import pprint


def get_rows_columns_map(table_result, blocks_map):
    rows = {}
    for relationship in table_result["Relationships"]:
        if relationship["Type"] == "CHILD":
            for child_id in relationship["Ids"]:
                cell = blocks_map[child_id]
                if cell["BlockType"] == "CELL":
                    row_index = cell["RowIndex"]
                    col_index = cell["ColumnIndex"]
                    if row_index not in rows:
                        # create new row
                        rows[row_index] = {}

                    # get the text value
                    rows[row_index][col_index] = get_text(cell, blocks_map)
    return rows


def get_text(result, blocks_map):
    text = ""
    if "Relationships" in result:
        for relationship in result["Relationships"]:
            if relationship["Type"] == "CHILD":
                for child_id in relationship["Ids"]:
                    word = blocks_map[child_id]
                    if word["BlockType"] == "WORD":
                        text += word["Text"] + " "
                    if word["BlockType"] == "SELECTION_ELEMENT":
                        if word["SelectionStatus"] == "SELECTED":
                            text += "X "
    return text


def get_table_csv_results(file_name):

    with open(file_name, "rb") as file:
        img_test = file.read()
        bytes_test = bytearray(img_test)
        print("Image loaded", file_name)

    # read in AWS creds using janky csv indexing (so we don't have to load in pandas)
    with open("data/raw-data/small/secret_keys.csv", "r") as file:
        my_reader = cv.reader(file, delimiter=",")
        creds = []
        for row in my_reader:
            creds = creds + row

    # process using image bytes
    # get the results
    client = boto3.client(
        "textract",
        region_name="us-east-1",
        aws_access_key_id=creds[2],
        aws_secret_access_key=creds[3],
    )

    response = client.analyze_document(
        Document={"Bytes": bytes_test}, FeatureTypes=["TABLES"]
    )

    # Get the text blocks
    blocks = response["Blocks"]
    # pprint(blocks)

    blocks_map = {}
    table_blocks = []
    for block in blocks:
        blocks_map[block["Id"]] = block
        if block["BlockType"] == "TABLE":
            print("jj")
            table_blocks.append(block)

    if len(table_blocks) <= 0:
        return "<b> NO Table FOUND </b>"

    csv = ""
    for index, table in enumerate(table_blocks):
        csv += generate_table_csv(table, blocks_map, index + 1)
        csv += "\n\n"

    return csv


def generate_table_csv(table_result, blocks_map, table_index):
    rows = get_rows_columns_map(table_result, blocks_map)

    table_id = "Table_" + str(table_index)

    # get cells.
    csv = "Table: {0}\n\n".format(table_id)

    for row_index, cols in rows.items():

        for col_index, text in cols.items():
            csv += '"{}"'.format(text) + ","
        csv += "\n"

    csv += "\n\n\n"
    return csv


def main(file_name):
    table_csv = get_table_csv_results(file_name)

    # Sometimes textract CSV has a header title and two blank rows we don't want
    table_csv = table_csv.replace("Table: Table_1\n\n", "")

    output_file = "data/processed-data/textract_bls_output.csv"

    # replace content
    with open(output_file, "wt") as fout:
        fout.write(table_csv)

    # show the results
    print("CSV OUTPUT FILE: ", output_file)


if __name__ == "__main__":
    file_name = sys.argv[1]
    main(file_name)
