package main

import (
	"items/internal/config"
	"items/internal/handlers"
	"items/internal/repo"
	"items/internal/server"
	"items/internal/service"

	_ "github.com/lib/pq"
	"github.com/sirupsen/logrus"
)

func main() {
	logrus.SetFormatter(new(logrus.JSONFormatter))

	cfg, err := config.Get()
	if err != nil {
		logrus.Fatalf("failed to get config: %s", err.Error())
	}

	db, err := repo.NewPostgresDB(repo.Config{
		Host:     cfg.Host,
		Port:     cfg.Port,
		Username: cfg.User,
		Password: cfg.Pass,
		DBName:   cfg.Name,
		SSLMode:  cfg.SSLMode,
	})
	if err != nil {
		logrus.Fatalf("failed to initialize db: %s", err.Error())
	}

	repos := repo.NewRepository(db)
	service := service.NewService(repos)
	handlers := handlers.NewHandler(service)

	srv := server.New(cfg.ServerPort, handlers.InitRoutes())
	if err := srv.Run(); err != nil {
		logrus.Fatal(err)
	}
}
