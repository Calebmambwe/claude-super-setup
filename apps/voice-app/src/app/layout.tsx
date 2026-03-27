import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Voice Brainstorm",
  description: "Speak your ideas. Claude builds them.",
  keywords: ["voice", "AI", "brainstorm", "Claude", "Anthropic"],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${inter.variable} font-sans bg-[#09090b] text-[#fafafa] antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
