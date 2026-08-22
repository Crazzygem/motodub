import { Router } from "express";
import { z } from "zod";
import { validate } from "../middlewares/validate.js";
import * as auth from "../controllers/auth.controller.js";

const router = Router();

const registerSchema = z.object({
  name: z.string().min(2),
  phone: z.string().min(6),
  email: z.email(),
  password: z.string().min(8),
  role: z.enum(["customer", "driver", "admin"]).default("customer"),
});

const loginSchema = z.object({
  email: z.email(),
  password: z.string().min(1),
});

router.post("/register", validate(registerSchema), auth.register);
router.post("/login", validate(loginSchema), auth.login);

export default router;
