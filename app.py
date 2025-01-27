import streamlit as st
import torch
import pandas as pd
import joblib

# Define the neural network model (same as in train_model.py)
class PricePredictorNN(torch.nn.Module):
    def __init__(self):
        super(PricePredictorNN, self).__init__()
        self.layer1 = torch.nn.Linear(5, 64)  # Input layer (5 features) to hidden layer (64 neurons)
        self.layer2 = torch.nn.Linear(64, 32)  # Hidden layer (32 neurons)
        self.layer3 = torch.nn.Linear(32, 16)  # Hidden layer (16 neurons)
        self.output = torch.nn.Linear(16, 1)  # Output layer (1 neuron for regression)
        self.relu = torch.nn.ReLU()  # Activation function

    def forward(self, x):
        x = self.relu(self.layer1(x))
        x = self.relu(self.layer2(x))
        x = self.relu(self.layer3(x))
        x = self.output(x)
        return x

# Load the saved model and scalers
def load_model_and_scalers():
    # Load the model architecture
    model = PricePredictorNN()
    # Load the model's state dictionary
    model.load_state_dict(torch.load("price_predictor_nn.pth"))
    model.eval()  # Set the model to evaluation mode
    # Load the scalers
    scaler_X = joblib.load("scaler_X.pkl")
    scaler_y = joblib.load("scaler_y.pkl")
    return model, scaler_X, scaler_y

# Custom CSS for modern design
st.markdown(
    """
    <style>
    .stApp {
        background-color: #f5f5f5;
    }
    .stButton>button {
        background-color: #4CAF50;
        color: white;
        border-radius: 5px;
        padding: 10px 20px;
        font-size: 16px;
    }
    .stMarkdown h1 {
        color: #2c3e50;
        font-family: 'Arial', sans-serif;
    }
    .stMarkdown h2 {
        color: #34495e;
        font-family: 'Arial', sans-serif;
    }
    .predicted-price {
        font-size: 32px;
        font-weight: bold;
        color: #27ae60;
        padding: 10px;
        background-color: #ecf0f1;
        border-radius: 5px;
        text-align: center;
    }
    </style>
    """,
    unsafe_allow_html=True,
)

# Streamlit app
def main():
    # Sidebar for additional information
    st.sidebar.title("About")
    st.sidebar.write("This app predicts house prices based on key features like square footage, grade, and year built.")
    st.sidebar.write("Enter the details of the house and click 'Predict' to get the estimated price.")

    # Main content
    st.title("🏠 House Price Predictor")
    st.write("Enter the details of the house to predict its price.")

    # Load the model and scalers
    try:
        model, scaler_X, scaler_y = load_model_and_scalers()
    except FileNotFoundError:
        st.error("Model or scalers not found. Please train the model first.")
        st.stop()

    # Organize input fields in columns
    col1, col2 = st.columns(2)

    with col1:
        sqft_living = st.number_input("Square Footage (sqft):", min_value=0, step=100, value=2000)
        grade = st.slider("Grade (1-13):", min_value=1, max_value=13, value=7)
        yr_built = st.slider("Year Built:", min_value=1900, max_value=2025, value=2000)

    with col2:
        sqft_lot = st.number_input("Lot Size (sqft):", min_value=0, step=100, value=5000)
        condition = st.slider("Condition (1-5):", min_value=1, max_value=5, value=3)

    # Predict button
    if st.button("Predict Price"):
        # Prepare input data
        user_input = {
            "sqft_living": sqft_living,
            "grade": grade,
            "yr_built": yr_built,
            "sqft_lot": sqft_lot,
            "condition": condition,
        }
        user_input_df = pd.DataFrame([user_input])

        # Normalize the input using the scaler
        try:
            normalized_input = scaler_X.transform(user_input_df)
        except ValueError as e:
            st.error(f"Input error: {e}")
            st.stop()

        # Convert to PyTorch tensor
        input_tensor = torch.tensor(normalized_input, dtype=torch.float32)

        # Make prediction
        try:
            with torch.no_grad():
                prediction = model(input_tensor).item()
                predicted_price = scaler_y.inverse_transform([[prediction]])[0][0]
                st.markdown(
                    f"<div class='predicted-price'>Predicted Price: ${predicted_price:,.2f}</div>",
                    unsafe_allow_html=True,
                )
        except Exception as e:
            st.error(f"Prediction error: {e}")

# Run the Streamlit app
if __name__ == "__main__":
    main()