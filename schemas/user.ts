import { z } from "zod";

export const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
  role: z.enum(["admin", "user", "viewer"]),
  password: z.string().min(8),
});

export type CreateUserInput = z.infer<typeof createUserSchema>;

export interface User {
  id: string;
  email: string;
  name: string;
  role: "admin" | "user" | "viewer";
  createdAt: Date;
}
