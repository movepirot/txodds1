FROM python:3.15.0a6-slim
COPY . .
RUN pip install -r requirements.txt
EXPOSE 5000
CMD ["flask","run","--host","0.0.0.0"]