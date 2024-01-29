# gunicorn_config.py
workers = 4  # You can adjust the number of workers based on your server's resources
bind = "0.0.0.0:5000"  # Binding to 0.0.0.0 allows external access