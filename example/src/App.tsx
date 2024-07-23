import { StyleSheet, View, NativeModules } from 'react-native';
import { WalletConnectNativeRn } from 'wallet-connect-native-rn';
console.log('NativeModules', NativeModules);
console.warn('WalletConnectNativeRn', WalletConnectNativeRn);
export default function App() {
  return <View style={styles.container} />;
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});
