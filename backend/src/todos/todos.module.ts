import { Module } from '@nestjs/common';
import { TodosService } from './todos/todos.service';
import { TodosController } from './todos/todos.controller';

@Module({
  providers: [TodosService],
  controllers: [TodosController]
})
export class TodosModule {}
