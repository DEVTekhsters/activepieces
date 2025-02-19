# Project Context

## Overview
Activepieces is a low-code automation tool that requires Docker-based deployment. The project uses a monorepo structure managed by nx, with multiple packages including community pieces for integration.

## Core Components
- Server API (Node.js)
- Community Pieces (Integration Components)
- Engine (Core Processing)
- React UI

## Memory Bank Files
This memory bank tracks:
- activeContext.md: Current session state and goals
- productContext.md: Project overview (this file)
- progress.md: Work tracking and next steps
- decisionLog.md: Key architectural decisions
- systemPatterns.md: Identified patterns and standards

## Project Goals
- Ensure all community pieces are built, packaged and registered in the image, so that there are no dependencies on external registries
- Maintain clean dependency management
- Support community piece management
- Enable efficient Docker-based deployment

## Technical Requirements
- Node.js 18.x environment
- Nx-based monorepo structure
- Docker containerization
- Offline-first deployment capability