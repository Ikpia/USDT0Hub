"use client";

interface StatCardProps {
  title: string;
  value: string;
  subtitle?: string;
  trend?: "up" | "down" | "neutral";
}

export function StatCard({ title, value, subtitle, trend }: StatCardProps) {
  return (
    <div className="glass p-6 glow-green">
      <p className="text-dark-400 text-sm font-medium">{title}</p>
      <p className="text-2xl font-bold text-white mt-1">{value}</p>
      {subtitle && (
        <p
          className={`text-sm mt-1 ${
            trend === "up"
              ? "text-primary-400"
              : trend === "down"
                ? "text-red-400"
                : "text-dark-400"
          }`}
        >
          {subtitle}
        </p>
      )}
    </div>
  );
}
