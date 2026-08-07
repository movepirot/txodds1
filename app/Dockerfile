FROM python:3.13-slim
RUN addgroup --system app && adduser --system --ingroup app app
COPY . .
RUN pip install -r requirements.txt
USER app
EXPOSE 5000
CMD ["flask","run","--host","0.0.0.0"]