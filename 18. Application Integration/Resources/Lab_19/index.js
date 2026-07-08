exports.handler = async (event) => {
    console.log('Received event:', JSON.stringify(event, null, 2));
    let body;

    try {

        switch (event.httpMethod) {
            case "GET":
                if (event.queryStringParameters != null) {
                    body = `Processing Get Product with query string parameters "${JSON.stringify(event.queryStringParameters)}"`;
                }
                else if (event.pathParameters != null) {
                    body = `Processing Get Product Id with "${event.pathParameters.id}"`;
                } else {
                    body = `Processing Get All Products`;
                }
                break;
            case "POST":
                let payload = JSON.parse(event.body);
                body = `Processing Post Product with "${JSON.stringify(payload)}"`;
                break;
            case "DELETE":
                if (event.pathParameters != null) {
                    body = `Processing Delete Product Id with "${event.pathParameters.id}"`;
                }
                break;
            default:
                throw new Error(`Unsupported route: "${event.httpMethod}"`);
        }

        console.log(body);
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: `Successfully finished operation: "${event.httpMethod}"`,
                body: body
            })
        };
    } catch (e) {
        console.error(e);
        return {
            statusCode: 400,
            body: JSON.stringify({
                message: "Failed to perform operation.",
                errorMsg: e.message
            })
        };
    }
};