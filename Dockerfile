FROM swift:latest as builder
WORKDIR /root

COPY Package.swift ./
RUN swift package resolve

COPY . .

RUN swift build -c release
