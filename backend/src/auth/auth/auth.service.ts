import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma/prisma.service';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
  ) { }

  async validateUser(
    email: string,
    pass: string,
  ): Promise<Record<string, unknown> | null> {
    const user = (await (this.prisma as any).user.findUnique({
      where: { email },
    })) as Record<string, unknown> | null;
    if (user && user.password === pass) {
      const result = { ...user };
      delete result.password;
      return result;
    }
    return null;
  }

  async login(user: {
    email: string;
    id: string;
    teamId: string | null;
    role: string;
  }) {
    const payload = {
      email: user.email,
      sub: user.id,
      teamId: user.teamId,
      role: user.role,
    };
    return {
      access_token: await this.jwtService.signAsync(payload),
    };
  }
}
