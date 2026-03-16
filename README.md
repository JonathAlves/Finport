# Finport

App **mobile (Flutter)** para registrar movimentos financeiros e exibir relatórios por **quinzena** e por **categoria**, usando **Supabase** como banco.

## 1) Criar tabelas no Supabase

Rode este SQL no **SQL Editor** do seu projeto Supabase:

```sql
create extension if not exists "uuid-ossp";

create table if not exists public.installment_purchases (
  id uuid primary key default uuid_generate_v4(),
  description text not null,
  installmentQuantity int not null,
  installmentValue numeric not null,
  currentInstallment int not null default 0,
  isActive boolean not null default true,
  createdAt timestamptz not null default now()
);

create table if not exists public.movements (
  id uuid primary key default uuid_generate_v4(),
  description text not null,
  value numeric not null,
  fortnight text not null, -- 'first' | 'second'
  isPaid boolean not null default false,
  category text not null, -- 'food' | 'house' | 'debits' | 'entertainment' | 'other'
  isInstallmentPurchase boolean not null default false,
  currentInstallment int null,
  installmentValue numeric null,
  installmentQuantity int null,
  installmentPurchaseId uuid null references public.installment_purchases(id),
  createdAt timestamptz not null default now()
);
```

## 2) Políticas (RLS) para 1 usuário (simples)

Se você não quiser lidar com autenticação agora, deixe as tabelas **sem RLS**:

1. Vá em **Database → Tables**.
2. Em `movements` e `installment_purchases`, desative **RLS**.

## 3) Rodar o app com as credenciais do Supabase

Você deve fornecer as credenciais via `--dart-define` (não ficam hardcoded no código):

```bash
flutter run ^
  --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co ^
  --dart-define=SUPABASE_ANON_KEY=SUA_ANON_KEY
```

## 4) Como funciona compra parcelada

- Ao marcar **“É uma compra parcelada?”**, você pode:
  - **Selecionar** uma compra parcelada existente (dropdown), ou
  - Criar uma **Nova** (botão “Nova”) informando **quantidade** e **valor da parcela**.
- Na criação de “Nova”, o campo **Valor (R$)** do movimento é atualizado automaticamente para \(quantidade × valor da parcela\).
- Ao criar um movimento associado a uma compra parcelada existente, o app associa ao **próximo número de parcela** e atualiza `currentInstallment` na tabela `installment_purchases`. Quando chega ao final, `isActive` vira `false` e ela some da lista.

# finport

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
