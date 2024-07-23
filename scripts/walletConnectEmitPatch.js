const fs = require('fs');
const path = require('path');

function replaceStringInFile(filePath, searchString, replaceString) {
  fs.readFile(filePath, 'utf8', (err, data) => {
    if (err) {
      return console.error(err);
    }

    const result = data.replace(new RegExp(searchString, 'g'), replaceString);

    fs.writeFile(filePath, result, 'utf8', (error) => {
      if (error) {
        return console.error(error);
      }
    });
  });
}

const emitFuncPath = path.join(
  __dirname,
  '../../ios/Pods/WalletConnectSwiftV2/Sources/WalletConnectSign/Engine/Common/SessionEngine.swift'
);

//prettier-ignore
const searchString = /logger.debug\("Could not find session for topic \\\(topic\)"\)/;
const replaceString = `logger.debug("Could not find session for topic \\(topic)")
              throw NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find session for topic \\(topic)"])
`;

replaceStringInFile(emitFuncPath, searchString, replaceString);
