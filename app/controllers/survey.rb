
# survey creator routes

post '/survey/upload' do
  survey = current_created_survey
  picture = Picture.new(question_id: params[:q_id]) 
  picture.image.store!(params[:file])
  picture.save
  redirect "/survey/edit/#{survey.id}"
end

post '/survey/new' do
  @survey = Survey.create(params.merge(:creator_id => current_user.id))
  set_created_survey(@survey)
  redirect "/survey/edit/#{@survey.id}"
end

get '/survey/edit/:id' do
  if current_user.id == Survey.find(params[:id]).creator_id
    @survey = Survey.find(params[:id])
    set_created_survey(@survey)
    erb :create_survey
  else
    redirect '/profile'
  end
end


# question routes

post '/question/new' do
  @question = current_created_survey.questions.create(:content => params[:content])
  params[:choices].split("\r").each do |c|
    @question.choices.create(:content => c.strip) unless c == ''
  end
  @survey = current_created_survey
  erb :_create_survey_question, :layout => false
end

get '/question/delete/:id' do
  if current_user.id == Question.find(params[:id]).survey.creator_id
    Question.delete(params[:id])
  end
  @survey = current_created_survey
  erb :_create_survey_question, :layout => false
end

delete '/question/picture/:question_id' do
  question = Question.find(params[:question_id])
  if current_user.id == question.survey.creator_id
    question.pictures.delete_all
  end
  @survey = current_created_survey
  erb :_create_survey_question, :layout => false
end

get '/survey/delete/:id' do
  if current_user.id == Survey.find(params[:id]).creator_id
    Survey.delete(params[:id])
  end
  @user = current_user
  erb :_my_surveys, :layout => false
end







# survey taker routes

get '/survey/:survey_id' do
  
  @survey = Survey.find(params[:survey_id])
  if !current_user && @survey.creator.name != "J"
    redirect "/"
  end
  
  if current_user && current_user.surveys.map{|s| s.id }.include?(params[:survey_id].to_i)
    redirect "/"
  end
  erb :rendered_survey
end

post '/survey/:survey_id' do
  content_type :json

  if current_user && current_user.surveys.map{|s| s.id }.include?(params[:survey_id].to_i)
    return status 400 #invalid submission
  end

  #hack to allow non-signed-in users to respond to a survey
  unless current_user
    u = User.new( email: "anon#{rand(1..999999999)}@anon.com", name: 'Anon' )
    u.password= "Tester1"
    u.save!
    session[:token] = u.id
  end

  # @params = params #to debug params
  if params[:questions] #make sure this isn't nil
    params[:questions].each_value do |choice_id|
      Answer.create( :choice_id => choice_id, :user_id => current_user.id  )
    end
  end

  cs = CompletedSurvey.new( :user_id => current_user.id, 
                          :survey_id => params[:survey_id] )

  if cs.valid?
    cs.save
    status 200
    {:redirect => "/survey/#{params[:survey_id]}/results"}.to_json
  else
    status 400 #invalid submission
    {:errors => cs.errors.full_messages}.to_json
  end
end

get '/survey/:survey_id/results' do
  @survey = Survey.find(params[:survey_id])
  @overall_respondents = @survey.num_respondents

  @q_response_rates =[]
  @question_strings= []
  @c_response_rates = [] #a nested array, each index of the inner array is a choice's num_respondents
  @choice_strings = [] #nested array, each index of the inner array is a choice's content

  @survey.questions.each_with_index do |question, i|
    @q_response_rates << question.num_respondents
    @question_strings << question.content

    @c_response_rates[i] = []
    @choice_strings[i] = []

    question.choices.each do |choice|
      @c_response_rates[i] << choice.num_respondents
      @choice_strings[i] << choice.content
    end
  end
  
  erb :survey_results
end