import { View } from 'react-native';

import { Button } from '@/components/Button';
import { Screen } from '@/components/Screen';
import { useAuth } from '@/providers/AuthProvider';

export default function SettingsScreen() {
  const { signOut } = useAuth();
  return (
    <Screen title="Settings">
      <View>
        <Button label="Sign out" onPress={signOut} />
      </View>
    </Screen>
  );
}
