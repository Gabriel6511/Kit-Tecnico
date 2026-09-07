@echo off
rem ============================================================================
rem  (c) 2026 Gabriel Navarro Bruno - Todos os direitos reservados.
rem  Publicado apenas para fins de portfolio/avaliacao tecnica. Uso pessoal e
rem  leitura sao permitidos; copia, redistribuicao ou reuso (total ou parcial)
rem  em outro projeto exigem autorizacao expressa do autor. Veja LICENSE na
rem  raiz do repositorio.
rem ============================================================================
title MODO EMERGENCIA - Diagnostico e Reparo
color 0C
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0EMERGENCIA.ps1"
