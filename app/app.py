from flask import Flask
from flask import request

app = Flask(__name__)

@app.route('/', methods = ['GET'])
def getUsers():
  if request.environ.get('HTTP_X_FORWARDED_FOR') is None:
    client_ip = request.environ['REMOTE_ADDR']
  else:
    client_ip = request.environ['HTTP_X_FORWARDED_FOR']
  return client_ip

@app.route('/health')
def healthCheck():
  return "200"

if __name__ == '__main__':
  app.run()
