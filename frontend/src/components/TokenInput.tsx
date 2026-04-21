"use client";

interface TokenInputProps {
  label: string;
  token: string;
  value: string;
  onChange: (value: string) => void;
  balance?: string;
  onMax?: () => void;
  disabled?: boolean;
  decimals?: number;
}

export function TokenInput({
  label,
  token,
  value,
  onChange,
  balance,
  onMax,
  disabled = false,
}: TokenInputProps) {
  return (
    <div className="glass p-4">
      <div className="flex justify-between items-center mb-2">
        <span className="text-sm text-dark-400">{label}</span>
        {balance && (
          <span className="text-sm text-dark-400">
            Balance: {balance}{" "}
            {onMax && (
              <button
                onClick={onMax}
                className="text-primary-400 hover:text-primary-300 ml-1"
              >
                MAX
              </button>
            )}
          </span>
        )}
      </div>
      <div className="flex items-center space-x-3">
        <input
          type="number"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder="0.00"
          disabled={disabled}
          className="flex-1 bg-transparent text-2xl font-medium text-white outline-none placeholder:text-dark-600 disabled:opacity-50"
        />
        <div className="px-3 py-2 bg-dark-700 rounded-xl text-sm font-medium text-white">
          {token}
        </div>
      </div>
    </div>
  );
}
