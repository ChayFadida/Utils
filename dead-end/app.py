from flask import Flask

app = Flask(__name__)

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def deadend(path):
    return "This is a dead-end route."

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
