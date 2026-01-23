const express = require("express");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 2567;

app.use(express.static(__dirname));

app.get("/sh", (req, res) => {
  res.sendFile(path.join(__dirname, "maskhål.html"));
});


app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "maskhål_ao.html"));
});


app.listen(PORT, () => {
  console.log(`listening on http://localhost:${PORT}`);
});
