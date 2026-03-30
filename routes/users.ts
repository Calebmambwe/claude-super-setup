import crypto from "node:crypto";
import { Router } from "express";
import type { Request, Response } from "express";
import { z } from "zod";

const createUserSchema = z.object({
  email: z.string().email("Invalid email address"),
  name: z.string().min(1, "Name is required"),
});

interface User {
  id: string;
  email: string;
  name: string;
}

const router = Router();

router.post("/", (req: Request, res: Response) => {
  const result = createUserSchema.safeParse(req.body);

  if (!result.success) {
    res.status(400).json({
      success: false,
      data: null,
      error: {
        code: "VALIDATION_ERROR",
        message: "Validation failed",
        details: result.error.flatten().fieldErrors,
      },
    });
    return;
  }

  const user: User = {
    id: crypto.randomUUID(),
    ...result.data,
  };

  res.status(201).json({
    success: true,
    data: user,
    error: null,
  });
});

export default router;
