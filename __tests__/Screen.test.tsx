import { render, screen } from '@testing-library/react-native';
import { Text } from 'react-native';

import { Screen } from '@/components/Screen';

describe('Screen', () => {
  it('shows the empty message when there are no children', async () => {
    await render(<Screen title="Members" emptyMessage="No members yet" />);
    expect(screen.getByText('Members')).toBeTruthy();
    expect(screen.getByText('No members yet')).toBeTruthy();
  });

  it('shows an error state', async () => {
    await render(<Screen title="Members" error="Boom" />);
    expect(screen.getByText('Boom')).toBeTruthy();
  });

  it('shows a loading indicator', async () => {
    await render(<Screen title="Members" loading />);
    expect(screen.getByLabelText('Loading')).toBeTruthy();
  });

  it('renders children', async () => {
    await render(
      <Screen title="Members">
        <Text>content</Text>
      </Screen>,
    );
    expect(screen.getByText('content')).toBeTruthy();
  });
});
