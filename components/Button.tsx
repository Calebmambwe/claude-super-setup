import type { ButtonHTMLAttributes, ReactNode } from "react";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
  loading?: boolean;
}

const buttonStyles = `
  .a11y-btn {
    display: inline-flex; align-items: center; justify-content: center;
    gap: 8px; padding: 8px 16px; border-radius: 6px;
    border: 1px solid #d1d5db; background: #fff; color: #111827;
    font-size: 14px; font-weight: 500; line-height: 20px;
    cursor: pointer; outline: none; transition: box-shadow 0.15s;
  }
  .a11y-btn:focus-visible { box-shadow: 0 0 0 2px #2563eb, 0 0 0 4px #bfdbfe; }
  .a11y-btn[aria-disabled="true"] {
    background: #f3f4f6; color: #9ca3af; cursor: not-allowed;
  }
  @keyframes a11y-btn-spin { to { transform: rotate(360deg); } }
  .a11y-btn-spinner {
    display: inline-block; width: 16px; height: 16px;
    border: 2px solid #d1d5db; border-top-color: #6b7280;
    border-radius: 50%; animation: a11y-btn-spin 0.6s linear infinite;
  }
`;

let stylesInjected = false;
function injectStyles() {
  if (stylesInjected || typeof document === "undefined") return;
  const sheet = document.createElement("style");
  sheet.textContent = buttonStyles;
  document.head.appendChild(sheet);
  stylesInjected = true;
}

export function Button({
  children,
  disabled = false,
  loading = false,
  onClick,
  className,
  type = "button",
  ...rest
}: ButtonProps) {
  injectStyles();
  const isDisabled = disabled || loading;

  return (
    <button
      type={type}
      onClick={isDisabled ? undefined : onClick}
      aria-disabled={isDisabled || undefined}
      aria-busy={loading || undefined}
      className={`a11y-btn${className ? ` ${className}` : ""}`}
      {...rest}
    >
      {loading && (
        <span
          className="a11y-btn-spinner"
          role="status"
          aria-label="Loading"
        />
      )}
      {children}
    </button>
  );
}
