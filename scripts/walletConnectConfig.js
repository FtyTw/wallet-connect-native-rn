const fs = require('fs');
const path = require('path');
const xcode = require('xcode');
const packageJsonPath = path.resolve(__dirname, '../../package.json');

const logError = console.error;

const currentDir = process.cwd();
const projectRoot = findIOSProjectRoot(currentDir);
const xcodeProjectPath = findXcodeProject(projectRoot);
const projectPath = path.join(xcodeProjectPath, 'project.pbxproj');
const filePath = path.join(projectRoot, 'assets/wallet-connect-configs.json');

function findXcodeProject(dir) {
  const files = fs.readdirSync(dir);
  const projectFile = files.find((file) => file.endsWith('.xcodeproj'));
  if (!projectFile) {
    throw new Error('Xcode project file not found');
  }
  return path.join(dir, projectFile);
}

function findIOSProjectRoot(directory) {
  let dir = directory;
  while (dir !== path.parse(dir).root) {
    const iosPath = path.join(dir, 'ios');
    if (fs.existsSync(iosPath) && fs.statSync(iosPath).isDirectory()) {
      return iosPath;
    }
    dir = path.dirname(dir);
  }
  throw new Error('iOS project directory not found');
}

function addFileToXcodeProject(pPath, fPath) {
  try {
    const project = xcode.project(pPath);
    project.parseSync();

    const groupKey =
      project.findPBXGroupKey({ name: 'Resources' }) ||
      project.findPBXGroupKey({ name: 'MainGroup' });
    if (!groupKey) {
      throw new Error('Resources group not found');
    }
    project.addResourceFile(
      fPath,
      { target: project.getFirstTarget().uuid },
      groupKey
    );

    fs.writeFileSync(projectPath, project.writeSync());
  } catch (e) {
    logError('Error:', e.message);
  }
}

const addWcConfig = () => {
  fs.readFile(packageJsonPath, 'utf8', (err, data) => {
    if (err) {
      logError('Error during reading package.json:' + err?.message);
      return;
    }

    try {
      const packageJson = JSON.parse(data);

      const androidOutputFile = path.resolve(
        __dirname,
        '../../android/app/src/main/assets/wallet-connect-configs.json'
      );
      const iosOutputFile = path.resolve(
        __dirname,
        '../../ios/assets/wallet-connect-configs.json'
      );
      const paths = [androidOutputFile, iosOutputFile];
      const walletConnectConfigs = packageJson['wallet-connect-native-rn'];

      const fileContent = JSON.stringify(walletConnectConfigs, null, 2);

      paths.forEach((fp) => {
        fs.writeFile(fp, fileContent, (e) => {
          if (e) {
            logError(
              'Error during writing to path: ' + fp + ': ' + err?.message
            );
            return;
          }

          logError('Data successfully written to: ' + fp);
          if (fp.includes('ios/assets')) {
            setTimeout(() => {
              addFileToXcodeProject(projectPath, filePath);
            }, 3000);
          }
        });
      });
    } catch (error) {
      logError('Error during parsing package.json:' + err?.message);
    }
  });
};

addWcConfig();
