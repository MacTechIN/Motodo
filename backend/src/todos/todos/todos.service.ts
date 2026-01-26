import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma/prisma.service';

@Injectable()
export class TodosService {
  constructor(private prisma: PrismaService) {}

  async create(
    userId: string,
    teamId: string,
    data: { content: string; priority: number; isSecret: boolean },
  ) {
    return await (this.prisma as any).todo.create({
      data: {
        ...data,
        createdBy: userId,
        teamId: teamId,
      },
    });
  }

  // Get user's own todos
  async findMyTodos(userId: string) {
    return await (this.prisma as any).todo.findMany({
      where: { createdBy: userId },
      orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
    });
  }

  // Get team todos (filtered)
  async findTeamTodos(teamId: string) {
    return await (this.prisma as any).todo.findMany({
      where: {
        teamId: teamId,
        isSecret: false, // Core Logic: Filter secret todos at DB level
      },
      orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
    });
  }
}
