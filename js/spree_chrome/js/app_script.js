
function doGet(qs, params) {
  if(typeof qs === "undefined") { return UiApp.createApplication(); }

  if(qs.parameter.redir) {
    return HtmlService.createHtmlOutput(
      "<a href='" + qs.parameter.redir + "'>Script successfully installed. Go back to your spreadsheet.</a>");
  }

  var id        = qs.parameter.spreadsheetId,
      ss        = SpreadsheetApp.openById(id).getSheets()[0],
      range     = ss.getRange(1, 1, ss.getLastRow(), ss.getLastColumn()),
      values    = range.getValues(),
      rowNumber = 0,
      row, cell;

  for(i in values){
    row = values[i];
    rowNumber++;
    for(var n=0,l=row.length;n<l;n++) {
      if(/\[\[ERROR/.test(row[n])){
        cell = ss.getRange(rowNumber,n+1);
        cell.setBackgroundColor("#FF0000");
        Logger.log("Found error. Setting value to: " + row[n].replace(/\[\[ERROR.+\]\]/,''));
        cell.setValue(row[n].replace(/\[\[ERROR.+\]\]/,''));
        SpreadsheetApp.flush();
      }
    }
  }

  return ss;
}