interface User {
  id: string;
  name: string;
  email: string;
  role: string;
}

interface UserCardProps {
  user: User;
  onEdit: (id: string) => void;
  onDelete: (id: string) => void;
}

export function UserCard({ user, onEdit, onDelete }: UserCardProps) {
  return (
    <div style={{ border: '1px solid #e2e8f0', borderRadius: 8, padding: 16 }}>
      <h3 style={{ margin: '0 0 4px' }}>{user.name}</h3>
      <p style={{ margin: '0 0 4px', color: '#64748b' }}>{user.email}</p>
      <p style={{ margin: '0 0 12px', color: '#94a3b8', fontSize: 14 }}>{user.role}</p>
      <div style={{ display: 'flex', gap: 8 }}>
        <button type="button" onClick={() => onEdit(user.id)}>
          Edit
        </button>
        <button type="button" onClick={() => onDelete(user.id)}>
          Delete
        </button>
      </div>
    </div>
  );
}
