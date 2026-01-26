import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma/prisma.service';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
  ) { }

  async validateUser(email: string, pass: string): Promise<Record<string, unknown> | null> {
    const user = await (this.prisma as any).user.findUnique({ where: { email } });
    if (user && (user as { password?: string }).password === pass) {
      const { password: __, ...result } = user as { password?: string };
      return result as Record<string, unknown>;
    }
    return null;
  }

  async login(user: { email: string; id: string; teamId: string | null; role: string }) {
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
