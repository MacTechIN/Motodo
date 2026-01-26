import { Test, TestingModule } from '@nestjs/testing';
import { TodosService } from './todos.service';
import { PrismaService } from '../../prisma/prisma/prisma.service';

describe('TodosService (Privacy Filtering)', () => {
  let service: TodosService;
  let prisma: PrismaService;

  const mockPrismaService = {
    todo: {
      findMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TodosService,
        { provide: PrismaService, useValue: mockPrismaService },
      ],
    }).compile();

    service = module.get<TodosService>(TodosService);
    prisma = module.get<PrismaService>(PrismaService);
  });

  it('should filter secret todos when fetching team list', async () => {
    const teamId = 'team-123';
    await service.findTeamTodos(teamId);

    expect(prisma.todo.findMany).toHaveBeenCalledWith({
      where: {
        teamId: teamId,
        isSecret: false, // This is the critical check
      },
      orderBy: expect.any(Array),
    });
  });

  it('should NOT filter secret todos when fetching own list', async () => {
    const userId = 'user-456';
    await service.findMyTodos(userId);

    expect(prisma.todo.findMany).toHaveBeenCalledWith({
      where: {
        createdBy: userId,
      },
      orderBy: expect.any(Array),
    });
  });
});
