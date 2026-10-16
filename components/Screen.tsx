import type { ReactNode } from 'react';
import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';

import { colors, spacing, typography } from '@/constants/theme';

type Props = {
  title: string;
  loading?: boolean;
  error?: string | null;
  emptyMessage?: string;
  children?: ReactNode;
};

/** Shared screen frame that handles loading / error / empty / content states. */
export function Screen({ title, loading, error, emptyMessage, children }: Props) {
  return (
    <View style={styles.container}>
      <Text accessibilityRole="header" style={styles.title}>
        {title}
      </Text>
      {loading ? (
        <ActivityIndicator accessibilityLabel="Loading" color={colors.accent} size="large" />
      ) : error ? (
        <Text accessibilityRole="alert" style={styles.error}>
          {error}
        </Text>
      ) : children ? (
        children
      ) : (
        <Text style={styles.muted}>{emptyMessage ?? 'Nothing here yet.'}</Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background, padding: spacing.md, gap: spacing.md },
  title: { ...typography.title, color: colors.text },
  muted: { ...typography.body, color: colors.textMuted },
  error: { ...typography.body, color: colors.danger },
});
