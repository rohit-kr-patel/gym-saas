import { Tabs } from 'expo-router';
import { SymbolView, type SymbolViewProps } from 'expo-symbols';

import { colors } from '@/constants/theme';

type TabDef = { name: string; title: string; icon: { ios: string; android: string; web: string } };

const TABS: TabDef[] = [
  {
    name: 'dashboard',
    title: 'Dashboard',
    icon: { ios: 'square.grid.2x2', android: 'dashboard', web: 'dashboard' },
  },
  { name: 'members', title: 'Members', icon: { ios: 'person.2', android: 'group', web: 'group' } },
  {
    name: 'attendance',
    title: 'Attendance',
    icon: { ios: 'checkmark.circle', android: 'event_available', web: 'event_available' },
  },
  {
    name: 'payments',
    title: 'Payments',
    icon: { ios: 'indianrupeesign.circle', android: 'payments', web: 'payments' },
  },
  {
    name: 'settings',
    title: 'Settings',
    icon: { ios: 'gearshape', android: 'settings', web: 'settings' },
  },
];

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.accent,
        tabBarInactiveTintColor: colors.textMuted,
        tabBarStyle: { backgroundColor: colors.surface, borderTopColor: colors.border, height: 64 },
        tabBarLabelStyle: { fontSize: 12 },
      }}>
      {TABS.map((tab) => (
        <Tabs.Screen
          key={tab.name}
          name={tab.name}
          options={{
            title: tab.title,
            tabBarAccessibilityLabel: tab.title,
            tabBarIcon: ({ color }) => (
              <SymbolView name={tab.icon as SymbolViewProps['name']} tintColor={color} size={26} />
            ),
          }}
        />
      ))}
    </Tabs>
  );
}
